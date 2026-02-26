import Foundation

extension URLSessionTask {

    private enum AssociatedKeys {
        nonisolated(unsafe) static var taskContext: UInt8 = 0
    }

    var taskContext: TaskContext? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.taskContext) as? TaskContext
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.taskContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
