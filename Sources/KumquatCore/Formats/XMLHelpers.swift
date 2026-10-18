import Foundation

extension XMLNode {
    /// All descendant elements with this local name, ignoring namespace prefixes.
    func elements(named name: String) -> [XMLElement] {
        var found: [XMLElement] = []
        var stack: [XMLNode] = children ?? []
        stack.reverse()
        while let node = stack.popLast() {
            if let element = node as? XMLElement, element.localName == name {
                found.append(element)
            }
            if let children = node.children {
                stack.append(contentsOf: children.reversed())
            }
        }
        return found
    }

    func firstElement(named name: String) -> XMLElement? {
        elements(named: name).first
    }
}

extension XMLElement {
    /// Attribute value by local name, so `r:id` matches "id".
    func attributeValue(_ name: String) -> String? {
        if let value = attribute(forName: name)?.stringValue { return value }
        return attributes?.first(where: { $0.localName == name })?.stringValue
    }

    /// Direct child elements with this local name.
    func children(named name: String) -> [XMLElement] {
        (children ?? []).compactMap { $0 as? XMLElement }.filter { $0.localName == name }
    }
}

enum Zip {
    static func extract(_ archive: URL, to directory: URL) async throws {
        try await Shell.run("/usr/bin/ditto", ["-x", "-k", archive.path, directory.path])
    }

    /// Zips the given entries (relative to `directory`) into `output`.
    static func create(_ output: URL, from directory: URL, entries: [String], store: Bool = false) async throws {
        let flags = store ? "-X0q" : "-Xr9q"
        try await Shell.run("/usr/bin/zip", [flags, output.path] + entries, in: directory)
    }
}
