import Foundation

#if canImport(Alamofire)
@_exported import protocol Alamofire.URLRepresentable
#else
public protocol URLRepresentable {
    func makeURL() throws -> URL
}

extension URL: URLRepresentable {
    public func makeURL() -> URL {
        return self
    }
}

extension String: URLRepresentable {
    public func makeURL() throws -> URL {
        struct InvalidURL: Error {}
        
        guard let url = URL(string: self) else {
            throw InvalidURL()
        }
        
        return url
    }
}
#endif
