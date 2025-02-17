import Common

class TreeNode: Equatable {
    private var _children: [TreeNode] = []
    var children: [TreeNode] { _children }
    fileprivate weak var _parent: NonLeafTreeNode? = nil
    var parent: NonLeafTreeNode? { _parent }
    private var adaptiveWeight: CGFloat
    private let _mruChildren: MruStack<TreeNode> = MruStack()
    // Usages:
    // - resize with mouse
    // - makeFloatingWindowsSeenAsTiling in focus command
    var lastAppliedLayoutVirtualRect: Rect? = nil  // as if inner gaps were always zero
    // Usages:
    // - resize with mouse
    // - move with mouse
    var lastAppliedLayoutPhysicalRect: Rect? = nil // with real inner gaps

    init(parent: NonLeafTreeNode, adaptiveWeight: CGFloat, index: Int) {
        self.adaptiveWeight = adaptiveWeight
        bind(to: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    fileprivate init() {
        adaptiveWeight = 0
    }

    /// See: ``getWeight(_:)``
    func setWeight(_ targetOrientation: Orientation, _ newValue: CGFloat) {
        switch parent?.kind {
        case .tilingContainer(let parent):
            if parent.orientation != targetOrientation {
                error("You can't change \(targetOrientation) weight of nodes located in \(parent.orientation) container")
            }
            if parent.layout != .tiles {
                error("Weight can be changed only for nodes whose parent is list")
            }
            adaptiveWeight = newValue
        case .workspace:
            error("Can't change weight for floating windows and workspace root containers")
        case nil:
            error("Can't change weight if TreeNode doesn't have parent")
        }
    }

    /// Weight itself doesn't make sense. The parent container controls semantics of weight
    func getWeight(_ targetOrientation: Orientation) -> CGFloat {
        switch parent?.kind {
        case .tilingContainer(let parent):
            return parent.orientation == targetOrientation ? adaptiveWeight : parent.getWeight(targetOrientation)
        case .workspace(let parent):
            switch genericKind {
            case .window: // self is a floating window
                error("Weight doesn't make sense for floating windows")
            case .tilingContainer: // root tiling container
                return parent.getWeight(targetOrientation)
            case .workspace:
                error("Workspaces can't be child")
            }
        case nil:
            error("Weight doesn't make sense for containers without parent")
        }
    }

    @discardableResult
    func bind(to newParent: NonLeafTreeNode, adaptiveWeight: CGFloat, index: Int) -> BindingData? {
        if _parent === newParent {
            error("Binding to the same parent doesn't make sense")
        }
        if newParent is Window {
            windowsCantHaveChildren()
        }
        let result = unbindIfPossible()

        if newParent === NilTreeNode.instance {
            return result
        }
        if adaptiveWeight == WEIGHT_AUTO {
            switch newParent.kind {
            case .tilingContainer(let newParent):
                self.adaptiveWeight = newParent.children.sumOf { $0.getWeight(newParent.orientation) }
                    .div(newParent.children.count)
                    ?? 1
            case .workspace:
                switch genericKind {
                case .window:
                    self.adaptiveWeight = WEIGHT_FLOATING
                case .tilingContainer:
                    self.adaptiveWeight = 1
                case .workspace:
                    error("Binding workspace to workspace is illegal")
                }
            }
        } else {
            self.adaptiveWeight = adaptiveWeight
        }
        newParent._children.insert(self, at: index != INDEX_BIND_LAST ? index : newParent._children.count)
        _parent = newParent
        // todo consider disabling automatic mru propogation
        // 1. "floating windows" in FocusCommand break the MRU because of that :(
        // 2. Misbehaved apps that abuse real window as popups https://github.com/nikitabobko/AeroSpace/issues/106 (the
        //    last appeared window, is not necessarily the one that has the focus)
        markAsMostRecentChild()
        return result
    }

    private func unbindIfPossible() -> BindingData? {
        guard let _parent else { return nil }

        let index = _parent._children.remove(element: self) ?? errorT("Can't find child in its parent")
        check(_parent._mruChildren.remove(self))
        self._parent = nil

        return BindingData(parent: _parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    func markAsMostRecentChild() {
        guard let _parent else { return }
        _parent._mruChildren.pushOrRaise(self)
        _parent.markAsMostRecentChild()
    }

    var mostRecentChild: TreeNode? {
        var iterator = _mruChildren.makeIterator()
        return iterator.next() ?? children.last
    }

    @discardableResult
    func unbindFromParent() -> BindingData {
        unbindIfPossible() ?? errorT("\(self) is already unbound")
    }

    static func ==(lhs: TreeNode, rhs: TreeNode) -> Bool {
        lhs === rhs
    }

    private var userData: [String:Any] = [:]
    func getUserData<T>(key: TreeNodeUserDataKey<T>) -> T? { userData[key.key] as! T? }
    func putUserData<T>(key: TreeNodeUserDataKey<T>, data: T) {
        userData[key.key] = data
    }
    @discardableResult
    func cleanUserData<T>(key: TreeNodeUserDataKey<T>) -> T? { userData.removeValue(forKey: key.key) as! T? }

    @discardableResult
    func nativeFocus() -> Bool { error("Not implemented") }
    func getRect() -> Rect? { error("Not implemented") }
}

struct TreeNodeUserDataKey<T> {
    let key: String
}

private let WEIGHT_FLOATING = CGFloat(-2)
/// Splits containers evenly if tiling.
///
/// Reset weight is bind to workspace (aka "floating windows")
let WEIGHT_AUTO = CGFloat(-1)

let INDEX_BIND_LAST = -1

struct BindingData {
    let parent: NonLeafTreeNode
    let adaptiveWeight: CGFloat
    let index: Int
}

class NilTreeNode: TreeNode, NonLeafTreeNode {
    private override init() {
        super.init()
    }
    static let instance = NilTreeNode()
}
