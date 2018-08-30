/// 
internal final class BindChangeContext<Bound> {
    let value: Bound
    var previousHandlers = Set<ObjectIdentifier>()
    
    init(value: Bound, initiator: AnyBinding<Bound>) {
        self.value = value
        
        for next in initiator.cascades {
            cascade(for: next)
        }
    }
    
    private func cascade(for cascade: CascadedBind<Bound>) {
        guard !self.previousHandlers.contains(cascade.id) else { return }
        
        if let binding = cascade.binding {
            self.previousHandlers.insert(cascade.id)
            
            binding.bound = value
            
            for next in binding.cascades {
                self.cascade(for: next)
            }
        }
    }
}

struct CascadedBind<Bound>: Hashable {
    weak var binding: AnyBinding<Bound>?
    let id: ObjectIdentifier
    
    init(binding: AnyBinding<Bound>) {
        self.id = ObjectIdentifier(binding)
        self.binding = binding
    }
    
    var hashValue: Int {
        return id.hashValue
    }
    
    static func ==(lhs: CascadedBind<Bound>, rhs: CascadedBind<Bound>) -> Bool {
        return lhs.id == rhs.id
    }
}

public class AnyBinding<Bound> {
    internal var bound: Bound {
        didSet {
            writeStream.next(bound)
        }
    }
    
    private let writeStream = WriteStream<Bound>()
    
    public var readStream: ReadStream<Bound> {
        return writeStream.listener
    }
    
    var cascades = Set<CascadedBind<Bound>>()
    
    internal init(bound: Bound) {
        self.bound = bound
    }
    
    internal func update(to value: Bound) {
        self.bound = value
        
        if cascades.count > 0 {
            _ = BindChangeContext<Bound>(value: bound, initiator: self)
        }
    }
    
    public func bind(to binding: AnyBinding<Bound>, bidirectionally: Bool = false) {
        binding.update(to: self.bound)
        
        self.cascades.insert(CascadedBind(binding: binding))
        
        if bidirectionally {
            binding.bind(to: self)
        }
    }
    
    public func bind<C: AnyObject>(to object: C, atKeyPath path: WritableKeyPath<C, Bound>) {
        weak var object = object
        
        func update(to currentvalue: Bound) {
            object?[keyPath: path] = bound
        }
        
        object?[keyPath: path] = self.bound
        _ = self.readStream.then(update)
    }
}

public final class Binding<Bound>: AnyBinding<Bound> {
    public var currentValue: Bound {
        get {
            return bound
        }
        set {
            bound = newValue
        }
    }
    
    public override func update(to value: Bound) {
        super.update(to: value)
    }
    
    public init(_ value: Bound) {
        super.init(bound: value)
    }
}

public final class ComputedBinding<Bound>: AnyBinding<Bound> {
    public private(set) var currentValue: Bound {
        get {
            return bound
        }
        set {
            update(to: newValue)
        }
    }
    
    internal init(_ value: Bound) {
        super.init(bound: value)
    }
}

extension AnyBinding {
    public func map<T>(_ mapper: @escaping (Bound) -> T) -> ComputedBinding<T> {
        let binding = ComputedBinding<T>(mapper(bound))
        
        _ = self.readStream.map(mapper).then(binding.update)
        
        return binding
    }
}

// TODO: Make binding codable where the contained value is codable
// TODO: Bidirectionally update computed bindings
