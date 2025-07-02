import Foundation

class WatchmodeService {
    static let shared = WatchmodeService()
    private init() {}
    
    let apiKey = "0zcKyNQ1D3SL9XHI3MWHHjvUZEv34HmA3UQdIccd"
    let netflixSourceId = 203 // Watchmode source ID for Netflix
    let region = "US"
    let cacheDirectory: URL = {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("watchmode_cache")
    }()
    let cacheExpiry: TimeInterval = 60 * 60 * 24 // 24 hours
    
    // MARK: - Watchmode API Response Structs (top-level)
    struct WatchmodeListResponse: Decodable {
        let titles: [WatchmodeTitle]
    }
    struct WatchmodeTitle: Decodable {
        let id: Int
        let title: String
        let year: Int?
        let type: String?
        let poster: String?
        let imdb_id: String?
        let tmdb_id: Int?
        let genre_names: [String]?
        let runtime_minutes: Int?
    }
    struct WatchmodeDetails: Decodable {
        let id: Int
        let title: String
        let year: Int?
        let type: String?
        let poster: String?
        let imdb_id: String?
        let tmdb_id: Int?
        let genre_names: [String]?
        let runtime_minutes: Int?
    }
    
    // MARK: - Trending Netflix US Fetch
    struct TrendingTitle: Identifiable, Codable {
        let id: Int
        let title: String
        let type: String
        let runtime_minutes: Int?
        let genres: [String]
        let plot_overview: String?
    }
    
    // MARK: - Fetch Top 25 for a service
    func fetchTop25(for service: String, completion: @escaping (Result<[MediaItem], Error>) -> Void) {
        guard service.lowercased() == "netflix" else {
            print("[WatchmodeService] Only Netflix supported for now.")
            completion(.success([]))
            return
        }
        let endpoint = "https://api.watchmode.com/v1/list-titles/"
        let params: [(String, String)] = [
            ("apiKey", apiKey),
            ("types", "movie"),
            ("sources", String(netflixSourceId)),
            ("regions", region),
            ("limit", "25"),
            ("sort_by", "popularity_desc"),
            ("release_year_start", "2024"),
            ("release_year_end", "2025"),
            ("fields", "genre_names,runtime_minutes")
        ]
        let movieURLString = endpoint + "?" + params.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        let showURLString = endpoint + "?" + params.map { key, value in
            if key == "types" { return "types=tv_series" } else { return "\(key)=\(value)" }
        }.joined(separator: "&")
        
        func fetchType(urlString: String, type: String, completion: @escaping (Result<[MediaItem], Error>) -> Void) {
            guard let url = URL(string: urlString) else {
                print("[WatchmodeService] Invalid URL for type \(type)")
                completion(.failure(NSError(domain: "WatchmodeService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
            print("[WatchmodeService] Fetching top 25 for type \(type) from URL: \(url)")
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("[WatchmodeService] Network error for type \(type): \(error)")
                    completion(.failure(error))
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("[WatchmodeService] HTTP status for type \(type): \(httpResponse.statusCode)")
                }
                guard let data = data else {
                    print("[WatchmodeService] No data received for type \(type)")
                    completion(.failure(NSError(domain: "WatchmodeService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                if let str = String(data: data, encoding: .utf8) {
                    print("[WatchmodeService] Raw API response for type \(type): \n\(str.prefix(500))\n...")
                }
                do {
                    let items = try self.parseMediaItems(from: data, service: service, type: type)
                    print("[WatchmodeService] Decoded \(items.count) items for type \(type)")
                    completion(.success(items))
                } catch {
                    print("❌ Decoding error for type \(type): \(error)")
                    completion(.failure(error))
                }
            }
            task.resume()
        }
        
        fetchType(urlString: movieURLString, type: "movie") { result1 in
            fetchType(urlString: showURLString, type: "tv_series") { result2 in
                switch (result1, result2) {
                case (.success(let movies), .success(let shows)):
                    completion(.success(movies + shows))
                case (.failure(let error), _), (_, .failure(let error)):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Fetch Top 100 for a service with caching and optional cache busting
    func fetchTop100(for service: String, cacheBusting: Bool = false, completion: @escaping (Result<[MediaItem], Error>) -> Void) {
        guard service.lowercased() == "netflix" else {
            print("[WatchmodeService] Only Netflix supported for now.")
            completion(.success([]))
            return
        }
        // Check cache unless cacheBusting is true
        if !cacheBusting, !cacheIsStale(service: service), let cached = loadFromCache(service: service) {
            print("[WatchmodeService] Loaded \(cached.count) items from cache for \(service)")
            completion(.success(cached))
            return
        }
        let endpoint = "https://api.watchmode.com/v1/list-titles/"
        let params: [(String, String)] = [
            ("apiKey", apiKey),
            ("types", "movie"),
            ("sources", String(netflixSourceId)),
            ("regions", region),
            ("limit", "100"),
            ("sort_by", "popularity_desc"),
            ("release_year_start", "2024"),
            ("release_year_end", "2025"),
            ("fields", "genre_names,runtime_minutes")
        ]
        let movieURLString = endpoint + "?" + params.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        let showURLString = endpoint + "?" + params.map { key, value in
            if key == "types" { return "types=tv_series" } else { return "\(key)=\(value)" }
        }.joined(separator: "&")
        
        func fetchType(urlString: String, type: String, completion: @escaping (Result<[MediaItem], Error>) -> Void) {
            guard let url = URL(string: urlString) else {
                print("[WatchmodeService] Invalid URL for type \(type)")
                completion(.failure(NSError(domain: "WatchmodeService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
            print("[WatchmodeService] Fetching top 100 for type \(type) from URL: \(url)")
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("[WatchmodeService] Network error for type \(type): \(error)")
                    completion(.failure(error))
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("[WatchmodeService] HTTP status for type \(type): \(httpResponse.statusCode)")
                }
                guard let data = data else {
                    print("[WatchmodeService] No data received for type \(type)")
                    completion(.failure(NSError(domain: "WatchmodeService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                if let str = String(data: data, encoding: .utf8) {
                    print("[WatchmodeService] Raw API response for type \(type): \n\(str.prefix(1000))\n...")
                }
                do {
                    let items = try self.parseMediaItems(from: data, service: service, type: type)
                    print("[WatchmodeService] Decoded \(items.count) items for type \(type)")
                    completion(.success(items))
                } catch {
                    print("❌ Decoding error for type \(type): \(error)")
                    completion(.failure(error))
                }
            }
            task.resume()
        }
        fetchType(urlString: movieURLString, type: "movie") { result1 in
            fetchType(urlString: showURLString, type: "tv_series") { result2 in
                switch (result1, result2) {
                case (.success(let movies), .success(let shows)):
                    let all = movies + shows
                    self.saveToCache(service: service, items: all)
                    completion(.success(all))
                case (.failure(let error), _), (_, .failure(let error)):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Fetch Top 5 for a service with details enrichment
    func fetchTop5WithDetails(for service: String, completion: @escaping (Result<[MediaItem], Error>) -> Void) {
        guard service.lowercased() == "netflix" else {
            print("[WatchmodeService] Only Netflix supported for now.")
            completion(.success([]))
            return
        }
        let endpoint = "https://api.watchmode.com/v1/list-titles/"
        let params: [(String, String)] = [
            ("apiKey", apiKey),
            ("types", "movie"),
            ("sources", String(netflixSourceId)),
            ("regions", region),
            ("limit", "5"),
            ("sort_by", "popularity_desc"),
            ("release_year_start", "2024"),
            ("release_year_end", "2025")
        ]
        let movieURLString = endpoint + "?" + params.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        let showURLString = endpoint + "?" + params.map { key, value in
            if key == "types" { return "types=tv_series" } else { return "\(key)=\(value)" }
        }.joined(separator: "&")
        
        func fetchType(urlString: String, type: String, completion: @escaping (Result<[MediaItem], Error>) -> Void) {
            guard let url = URL(string: urlString) else {
                print("[WatchmodeService] Invalid URL for type \(type)")
                completion(.failure(NSError(domain: "WatchmodeService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
            print("[WatchmodeService] Fetching top 5 for type \(type) from URL: \(url)")
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("[WatchmodeService] Network error for type \(type): \(error)")
                    completion(.failure(error))
                    return
                }
                guard let data = data else {
                    print("[WatchmodeService] No data received for type \(type)")
                    completion(.failure(NSError(domain: "WatchmodeService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                let decoder = JSONDecoder()
                do {
                    let response = try decoder.decode(WatchmodeListResponse.self, from: data)
                    print("[WatchmodeService] Got \(response.titles.count) top \(type)s, fetching details...")
                    var items: [MediaItem] = Array(repeating: MediaItem(id: "", title: "", year: nil, type: type, genres: [], directors: [], cast: [], duration: 0, viewCount: 0, summary: "", posterURL: nil, seriesTitle: nil, lastRecommended: nil, platforms: [service], country: self.region.lowercased()), count: response.titles.count)
                    let group = DispatchGroup()
                    for (i, raw) in response.titles.enumerated() {
                        group.enter()
                        let detailsURL = "https://api.watchmode.com/v1/title/\(raw.id)/details/?apiKey=\(self.apiKey)"
                        guard let url = URL(string: detailsURL) else {
                            print("[WatchmodeService] Invalid details URL for id \(raw.id)")
                            group.leave()
                            continue
                        }
                        let task = URLSession.shared.dataTask(with: url) { data, response, error in
                            defer { group.leave() }
                            if let error = error {
                                print("[WatchmodeService] Detail fetch error for id \(raw.id): \(error)")
                                return
                            }
                            guard let data = data else {
                                print("[WatchmodeService] No data for details id \(raw.id)")
                                return
                            }
                            do {
                                let details = try decoder.decode(WatchmodeDetails.self, from: data)
                                print("[WatchmodeService] Details for id \(details.id): genres=\(details.genre_names ?? []), duration=\(details.runtime_minutes ?? 0)")
                                let resolvedType: String = {
                                    if type == "movie" { return details.type ?? "movie" }
                                    else { return details.type ?? "tv_series" }
                                }()
                                items[i] = MediaItem(
                                    id: String(details.id),
                                    title: details.title,
                                    year: details.year,
                                    type: resolvedType,
                                    genres: details.genre_names ?? [],
                                    directors: [],
                                    cast: [],
                                    duration: details.runtime_minutes ?? 0,
                                    viewCount: 0,
                                    summary: "",
                                    posterURL: details.poster,
                                    seriesTitle: nil,
                                    lastRecommended: nil,
                                    platforms: [service],
                                    country: self.region.lowercased()
                                )
                            } catch {
                                print("[WatchmodeService] Failed to decode details for id \(raw.id): \(error)")
                            }
                        }
                        task.resume()
                    }
                    group.notify(queue: .main) {
                        print("[WatchmodeService] All details fetched for type \(type)")
                        completion(.success(items))
                    }
                } catch {
                    print("[WatchmodeService] Failed to decode top \(type)s: \(error)")
                    completion(.failure(error))
                }
            }
            task.resume()
        }
        fetchType(urlString: movieURLString, type: "movie") { result1 in
            fetchType(urlString: showURLString, type: "tv_series") { result2 in
                switch (result1, result2) {
                case (.success(let movies), .success(let shows)):
                    completion(.success(movies + shows))
                case (.failure(let error), _), (_, .failure(let error)):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Parse JSON to [MediaItem]
    private func parseMediaItems(from data: Data, service: String, type: String) throws -> [MediaItem] {
        let decoder = JSONDecoder()
        let response = try decoder.decode(WatchmodeListResponse.self, from: data)
        print("[WatchmodeService] parseMediaItems: response.titles.count = \(response.titles.count)")
        let items: [MediaItem] = response.titles.map { raw in
            MediaItem(
                id: String(raw.id),
                title: raw.title,
                year: raw.year,
                type: raw.type ?? type,
                genres: raw.genre_names ?? [],
                directors: [],
                cast: [],
                duration: raw.runtime_minutes ?? 0,
                viewCount: 0,
                summary: "",
                posterURL: raw.poster,
                seriesTitle: nil,
                lastRecommended: nil,
                platforms: [service],
                country: self.region.lowercased()
            )
        }
        print("[WatchmodeService] Parsed \(items.count) items from Watchmode API")
        return items
    }
    
    // MARK: - Cache Management
    private func cacheFileURL(for service: String) -> URL {
        return cacheDirectory.appendingPathComponent("watchmode_\(service.lowercased()).json")
    }
    
    func saveToCache(service: String, items: [MediaItem]) {
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            let url = cacheFileURL(for: service)
            let data = try JSONEncoder().encode(items)
            try data.write(to: url)
            print("[WatchmodeService] Saved \(items.count) items to cache for \(service) at \(url.path)")
        } catch {
            print("[WatchmodeService] Failed to save cache for \(service): \(error)")
        }
    }
    
    func loadFromCache(service: String) -> [MediaItem]? {
        let url = cacheFileURL(for: service)
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("[WatchmodeService] No cache file for \(service) at \(url.path)")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let items = try JSONDecoder().decode([MediaItem].self, from: data)
            print("[WatchmodeService] Loaded \(items.count) items from cache for \(service)")
            return items
        } catch {
            print("[WatchmodeService] Failed to load cache for \(service): \(error)")
            return nil
        }
    }
    
    func cacheIsStale(service: String) -> Bool {
        let url = cacheFileURL(for: service)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return true // No cache or can't read date
        }
        return Date().timeIntervalSince(modDate) > cacheExpiry
    }
    
    // MARK: - Trending Netflix US Fetch
    func fetchTop100TrendingNetflixUS(completion: @escaping (Result<[TrendingTitle], Error>) -> Void) {
        let endpoint = "https://api.watchmode.com/v1/list-titles/"
        let params: [(String, String)] = [
            ("apiKey", "0zcKyNQ1D3SL9XHI3MWHHjvUZEv34HmA3UQdIccd"),
            ("source_ids", "355"), // Netflix
            ("regions", "US"),
            ("language", "en"),
            ("limit", "100"),
            ("sort_by", "popularity_desc")
        ]
        let urlString = endpoint + "?" + params.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "WatchmodeService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error)); return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "WatchmodeService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"]))); return
            }
            struct ListResponse: Codable { let titles: [TitleSummary] }
            struct TitleSummary: Codable { let id: Int }
            do {
                let list = try JSONDecoder().decode(ListResponse.self, from: data)
                let ids = list.titles.map { $0.id }
                var trending: [TrendingTitle] = Array(repeating: TrendingTitle(id: 0, title: "", type: "", runtime_minutes: nil, genres: [], plot_overview: nil), count: ids.count)
                let group = DispatchGroup()
                for (i, id) in ids.enumerated() {
                    group.enter()
                    let detailsURL = "https://api.watchmode.com/v1/title/\(id)/details/?apiKey=0zcKyNQ1D3SL9XHI3MWHHjvUZEv34HmA3UQdIccd"
                    guard let url = URL(string: detailsURL) else { group.leave(); continue }
                    URLSession.shared.dataTask(with: url) { data, _, _ in
                        defer { group.leave() }
                        guard let data = data else { return }
                        struct Details: Codable {
                            let id: Int
                            let title: String
                            let type: String
                            let runtime_minutes: Int?
                            let genre_names: [String]?
                            let plot_overview: String?
                        }
                        if let details = try? JSONDecoder().decode(Details.self, from: data) {
                            trending[i] = TrendingTitle(
                                id: details.id,
                                title: details.title,
                                type: details.type,
                                runtime_minutes: details.runtime_minutes,
                                genres: details.genre_names ?? [],
                                plot_overview: details.plot_overview
                            )
                        }
                    }.resume()
                }
                group.notify(queue: .main) {
                    let filtered = trending.filter { !$0.title.isEmpty }
                    completion(.success(filtered))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
} 