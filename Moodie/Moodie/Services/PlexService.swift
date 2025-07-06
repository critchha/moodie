import Foundation

class PlexService {
    static let shared = PlexService()
    private init() {}
    
    // MARK: - Public API
    func fetchMediaLibrary(completion: @escaping (Result<[MediaItem], Error>) -> Void) {
        print("[PlexService] fetchMediaLibrary called. Current userProfile.selectedServices: \(UserProfileStore.shared.load().selectedServices)")
        guard let token = KeychainService.shared.getToken() else {
            completion(.failure(NSError(domain: "PlexService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No Plex token found."])));
            return
        }
        fetchServers(token: token) { result in
            switch result {
            case .success(let servers):
                guard let server = servers.first else {
                    completion(.failure(NSError(domain: "PlexService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No Plex servers found."])));
                    return
                }
                self.fetchLibrarySections(server: server, token: token) { result in
                    switch result {
                    case .success(let sections):
                        // For simplicity, fetch all items from all sections (movies, shows)
                        let group = DispatchGroup()
                        var allItems: [MediaItem] = []
                        var fetchError: Error?
                        for section in sections {
                            group.enter()
                            self.fetchMediaItems(server: server, section: section, token: token) { result in
                                switch result {
                                case .success(let items):
                                    allItems.append(contentsOf: items)
                                case .failure(let error):
                                    fetchError = error
                                }
                                group.leave()
                            }
                        }
                        group.notify(queue: .main) {
                            if let error = fetchError {
                                completion(.failure(error))
                            } else {
                                completion(.success(allItems))
                            }
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Step 1: Discover Servers
    private func fetchServers(token: String, completion: @escaping (Result<[PlexServer], Error>) -> Void) {
        let url = URL(string: "https://plex.tv/api/resources?includeHttps=1&X-Plex-Token=\(token)")!
        var request = URLRequest(url: url)
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "PlexService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No data from Plex resources."]))); return
            }
            let servers = PlexXMLParser.parseServers(from: data)
            if servers.isEmpty {
                completion(.failure(NSError(domain: "PlexService", code: 4, userInfo: [NSLocalizedDescriptionKey: "No servers found in XML."]))); return
            }
            completion(.success(servers))
        }
        task.resume()
    }
    
    // MARK: - Step 2: Fetch Library Sections
    private func fetchLibrarySections(server: PlexServer, token: String, completion: @escaping (Result<[PlexLibrarySection], Error>) -> Void) {
        guard let baseURL = server.baseURL else {
            completion(.failure(NSError(domain: "PlexService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid server base URL."]))); return
        }
        let url = URL(string: "\(baseURL)/library/sections?X-Plex-Token=\(token)")!
        var request = URLRequest(url: url)
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "PlexService", code: 6, userInfo: [NSLocalizedDescriptionKey: "No data from Plex library sections."]))); return
            }
            let sections = PlexXMLParser.parseLibrarySections(from: data)
            if sections.isEmpty {
                completion(.failure(NSError(domain: "PlexService", code: 7, userInfo: [NSLocalizedDescriptionKey: "No library sections found in XML."]))); return
            }
            completion(.success(sections))
        }
        task.resume()
    }
    
    // MARK: - Step 3: Fetch Media Items
    private func fetchMediaItems(server: PlexServer, section: PlexLibrarySection, token: String, completion: @escaping (Result<[MediaItem], Error>) -> Void) {
        guard let baseURL = server.baseURL else {
            completion(.failure(NSError(domain: "PlexService", code: 8, userInfo: [NSLocalizedDescriptionKey: "Invalid server base URL."]))); return
        }
        let url = URL(string: "\(baseURL)/library/sections/\(section.key)/all?X-Plex-Token=\(token)")!
        var request = URLRequest(url: url)
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "PlexService", code: 9, userInfo: [NSLocalizedDescriptionKey: "No data from Plex media items."]))); return
            }
            let items = PlexXMLParser.parseMediaItems(from: data, baseURL: baseURL, token: token)
            completion(.success(items))
        }
        task.resume()
    }

    func authenticate(completion: @escaping (Bool) -> Void) {
        print("[PlexService] Starting authentication. Current userProfile.selectedServices: \(UserProfileStore.shared.load().selectedServices)")
        // ... existing code ...
    }
}

// MARK: - PlexServer, PlexLibrarySection, and XML Parsing Helpers
struct PlexServer {
    let name: String
    let baseURL: String?
}

struct PlexLibrarySection {
    let key: String
    let title: String
    let type: String // movie, show, etc.
}

class PlexXMLParser {
    // Parse servers from resources XML
    static func parseServers(from data: Data) -> [PlexServer] {
        var servers: [PlexServer] = []
        let parser = XMLParser(data: data)
        let delegate = PlexServersXMLDelegate()
        parser.delegate = delegate
        parser.parse()
        servers = delegate.servers
        return servers
    }
    // Parse library sections from XML
    static func parseLibrarySections(from data: Data) -> [PlexLibrarySection] {
        var sections: [PlexLibrarySection] = []
        let parser = XMLParser(data: data)
        let delegate = PlexLibrarySectionsXMLDelegate()
        parser.delegate = delegate
        parser.parse()
        sections = delegate.sections
        return sections
    }
    // Parse media items from XML
    static func parseMediaItems(from data: Data, baseURL: String, token: String) -> [MediaItem] {
        var items: [MediaItem] = []
        let parser = XMLParser(data: data)
        let delegate = PlexMediaItemsXMLDelegate()
        delegate.baseURL = baseURL
        parser.delegate = delegate
        parser.parse()
        // Patch in the token for poster URLs
        items = delegate.items.map { item in
            if let posterURL = item.posterURL, posterURL.contains("X-Plex-Token=") == false {
                let urlWithToken = posterURL + "?X-Plex-Token=\(token)"
                var newItem = item
                newItem = MediaItem(
                    id: item.id,
                    title: item.title,
                    year: item.year,
                    type: item.type,
                    genres: item.genres,
                    directors: item.directors,
                    cast: item.cast,
                    duration: item.duration,
                    viewCount: item.viewCount,
                    summary: item.summary,
                    posterURL: urlWithToken,
                    seriesTitle: item.seriesTitle,
                    lastRecommended: item.lastRecommended,
                    platforms: ["Plex"],
                    country: "us"
                )
                return newItem
            }
            return item
        }
        return items
    }
}

// MARK: - XML Delegates (implementations omitted for brevity, but should parse XML into models)
class PlexServersXMLDelegate: NSObject, XMLParserDelegate {
    var servers: [PlexServer] = []
    private var currentAttributes: [String: String] = [:]
    private var currentDeviceName: String = "Unknown"
    private var foundBaseURL: String? = nil
    private var inDevice = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "Device" {
            inDevice = true
            currentAttributes = attributeDict
            currentDeviceName = attributeDict["name"] ?? "Unknown"
            foundBaseURL = nil
        } else if inDevice && elementName == "Connection" {
            // Prefer local connections, but fallback to public if needed
            // Use uri attribute as baseURL
            if let uri = attributeDict["uri"], foundBaseURL == nil {
                foundBaseURL = uri
            }
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "Device" {
            servers.append(PlexServer(name: currentDeviceName, baseURL: foundBaseURL))
            inDevice = false
            foundBaseURL = nil
        }
    }
}

class PlexLibrarySectionsXMLDelegate: NSObject, XMLParserDelegate {
    var sections: [PlexLibrarySection] = []
    private var currentAttributes: [String: String] = [:]
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "Directory" {
            let key = attributeDict["key"] ?? ""
            let title = attributeDict["title"] ?? ""
            let type = attributeDict["type"] ?? ""
            sections.append(PlexLibrarySection(key: key, title: title, type: type))
        }
    }
}

class PlexMediaItemsXMLDelegate: NSObject, XMLParserDelegate {
    var items: [MediaItem] = []
    private var currentAttributes: [String: String] = [:]
    var baseURL: String? = nil
    private var posterPrintCount = 0
    private var parsingMediaItem: Bool = false
    private var currentMediaItemAttributes: [String: String] = [:]
    private var currentGenres: [String] = []
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        // Add support for Directory elements with type="show" (TV Shows)
        if elementName == "Video" || elementName == "Movie" || elementName == "Episode" || (elementName == "Directory" && attributeDict["type"] == "show") {
            parsingMediaItem = true
            currentMediaItemAttributes = attributeDict
            currentGenres = []
        } else if parsingMediaItem && elementName == "Genre", let tag = attributeDict["tag"] {
            currentGenres.append(tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if parsingMediaItem && (elementName == "Video" || elementName == "Movie" || elementName == "Episode" || (elementName == "Directory" && currentMediaItemAttributes["type"] == "show")) {
            let attr = currentMediaItemAttributes
            let id = attr["ratingKey"] ?? UUID().uuidString
            let title = attr["title"] ?? "Untitled"
            let year = Int(attr["year"] ?? "")
            let type = attr["type"] ?? (elementName == "Directory" ? "show" : "movie")
            let directors = (attr["director"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let cast = (attr["role"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let duration = Int((attr["duration"] ?? "0")) ?? 0
            let minutes = duration > 0 ? duration / 60000 : 0
            let viewCount = Int(attr["viewCount"] ?? "0") ?? 0
            let summary = attr["summary"] ?? ""
            let posterPath = attr["thumb"]
            let posterURL = (baseURL != nil && posterPath != nil) ? "\(baseURL!)\(posterPath!)" : nil
            // Parse seriesTitle for episodes/shows
            let seriesTitle: String? = {
                if type == "show" {
                    return title
                } else if let grandparent = attr["grandparentTitle"] {
                    return grandparent
                } else if let parent = attr["parentTitle"] {
                    return parent
                } else {
                    return nil
                }
            }()
            items.append(MediaItem(
                id: id,
                title: title,
                year: year,
                type: type,
                genres: currentGenres,
                directors: directors,
                cast: cast,
                duration: minutes,
                viewCount: viewCount,
                summary: summary,
                posterURL: posterURL,
                seriesTitle: seriesTitle,
                lastRecommended: nil,
                platforms: ["Plex"],
                country: "us"
            ))
            parsingMediaItem = false
            currentMediaItemAttributes = [:]
            currentGenres = []
        }
    }
} 