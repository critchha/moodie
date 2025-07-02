// FlixPatrolService is now deprecated in favor of WatchmodeService. All references to FlixPatrolService should be removed from the app. This file is retained for future reference.

import Foundation

class FlixPatrolService {
    static let shared = FlixPatrolService()
    private init() {}
    
    // Supported streaming services and their FlixPatrol API slugs
    let supportedServices = [
        "Netflix", "Hulu", "HBO", "Paramount+", "Apple TV+", "Disney+"
    ]
    private let serviceSlugMap: [String: String] = [
        "Netflix": "netflix",
        "Hulu": "hulu",
        "HBO": "hbo",
        "Paramount+": "paramount",
        "Apple TV+": "apple-tv",
        "Disney+": "disney"
    ]
    let apiKey = "aku_80kB3PlONbeWiHX60xVfZLm4"
    let country = "us"
    let cacheDirectory: URL = {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("flixpatrol_cache")
    }()
    let cacheExpiry: TimeInterval = 60 * 60 * 24 // 24 hours
    
    // Helper to get the most recent Monday as a string (yyyy-MM-dd)
    private func mostRecentMonday() -> String {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        // In Calendar, Sunday = 1, Monday = 2, ..., Saturday = 7
        let daysSinceMonday = (weekday + 5) % 7
        let lastMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: now)!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: lastMonday)
    }
    
    // MARK: - Fetch Top 100 for a service
    func fetchTop100(for service: String, completion: @escaping (Result<[MediaItem], Error>) -> Void) {
        print("[FlixPatrolService] fetchTop100 called for service: \(service)")
        guard serviceSlugMap[service] == "netflix" else {
            print("[FlixPatrolService] Only Netflix supported for now.")
            completion(.success([]))
            return
        }
        let endpoint = "https://flixpatrol.com/api/v1.4/data/"
        let region = "4672" // US
        let streaming = "656" // Netflix
        let company = "656" // Netflix
        let year = "2024"
        let apiKey = self.apiKey
        let filter = "title"
        let set = "4" // Use set=4 for both movies and shows (confirmed by working API)

        func fetchType(_ type: String, completion: @escaping (Result<[MediaItem], Error>) -> Void) {
            var urlComponents = URLComponents(string: endpoint)!
            urlComponents.queryItems = [
                URLQueryItem(name: "set", value: set),
                URLQueryItem(name: "streaming", value: streaming),
                URLQueryItem(name: "region", value: region),
                URLQueryItem(name: "type", value: type), // 1 = movie, 2 = show
                URLQueryItem(name: "country", value: region),
                URLQueryItem(name: "year", value: year),
                URLQueryItem(name: "company", value: company),
                URLQueryItem(name: "filter", value: filter),
                URLQueryItem(name: "query", value: ""),
                URLQueryItem(name: "top25", value: "1"), // Only fetch top 25
                URLQueryItem(name: "api", value: apiKey)
            ]
            guard let url = urlComponents.url else {
                print("[FlixPatrolService] Invalid URL for type \(type)")
                completion(.failure(NSError(domain: "FlixPatrolService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
            print("[FlixPatrolService] Fetching top 25 for type \(type) from URL: \(url)")
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("[FlixPatrolService] Network error for type \(type): \(error)")
                    completion(.failure(error))
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("[FlixPatrolService] HTTP status for type \(type): \(httpResponse.statusCode)")
                } else {
                    print("[FlixPatrolService] No HTTPURLResponse for type \(type)")
                }
                guard let data = data else {
                    print("[FlixPatrolService] No data received for type \(type)")
                    completion(.failure(NSError(domain: "FlixPatrolService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                if let str = String(data: data, encoding: .utf8) {
                    print("[FlixPatrolService] Raw API response for type \(type): \n\(str.prefix(500))\n...")
                }
                do {
                    let items = try self.parseMediaItems(from: data, service: service)
                    print("[FlixPatrolService] Decoded \(items.count) items for type \(type)")
                    completion(.success(items))
                } catch {
                    print("❌ Decoding error for type \(type): \(error)")
                    completion(.failure(error))
                }
            }
            task.resume()
        }

        fetchType("1") { result1 in // Movies
            fetchType("2") { result2 in // Shows
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
    private func parseMediaItems(from data: Data, service: String) throws -> [MediaItem] {
        struct FlixPatrolResponse: Decodable {
            let list: [FlixPatrolItem]
        }
        struct FlixPatrolItem: Decodable {
            let id: Int
            let name: String
            let url: String?
            let imdb: String?
            let tmdb: String?
            let premiere: String?
            let type: String?
            let genre: String?
            let company: String?
            let ranking: Int?
            let value: Int?
            let updated: String?
            // Add more fields as needed from the API response
        }
        let decoder = JSONDecoder()
        let response = try decoder.decode(FlixPatrolResponse.self, from: data)
        print("[FlixPatrolService] parseMediaItems: response.list.count = \(response.list.count)")
        let items: [MediaItem] = response.list.map { raw in
            MediaItem(
                id: String(raw.id),
                title: raw.name,
                year: raw.premiere.flatMap { Int($0.prefix(4)) },
                type: raw.type ?? "movie",
                genres: raw.genre.map { [$0] } ?? [],
                directors: [],
                cast: [],
                duration: 0,
                viewCount: raw.value ?? 0,
                summary: "",
                posterURL: raw.url,
                seriesTitle: nil,
                lastRecommended: nil,
                platforms: [service],
                country: country
            )
        }
        print("[FlixPatrolService] Parsed \(items.count) items from FlixPatrol API")
        return items
    }
    
    // MARK: - Cache Management
    private func cacheFileURL(for service: String) -> URL {
        return cacheDirectory.appendingPathComponent("flixpatrol_\(service.lowercased()).json")
    }
    
    func saveToCache(service: String, items: [MediaItem]) {
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            let url = cacheFileURL(for: service)
            let data = try JSONEncoder().encode(items)
            try data.write(to: url)
            print("[FlixPatrolService] Saved \(items.count) items to cache for \(service) at \(url.path)")
        } catch {
            print("[FlixPatrolService] Failed to save cache for \(service): \(error)")
        }
    }
    
    func loadFromCache(service: String) -> [MediaItem] {
        let url = cacheFileURL(for: service)
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("[FlixPatrolService] No cache file for \(service) at \(url.path)")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let items = try JSONDecoder().decode([MediaItem].self, from: data)
            print("[FlixPatrolService] Loaded \(items.count) items from cache for \(service)")
            return items
        } catch {
            print("[FlixPatrolService] Failed to load cache for \(service): \(error)")
            return []
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
    
    // MARK: - Deduplication
    func dedupedItems(for services: [String]) -> [MediaItem] {
        var merged: [String: MediaItem] = [:]
        for service in services {
            let items = loadFromCache(service: service)
            for item in items {
                if var existing = merged[item.id] {
                    // Merge platforms
                    for platform in item.platforms where !existing.platforms.contains(platform) {
                        existing.platforms.append(platform)
                    }
                    merged[item.id] = existing
                } else {
                    merged[item.id] = item
                }
            }
        }
        return Array(merged.values)
    }
    
    // MARK: - Public API
    func refreshAllCachesIfNeeded(for services: [String], completion: @escaping () -> Void) {
        let group = DispatchGroup()
        for service in services {
            if cacheIsStale(service: service) {
                group.enter()
                fetchTop100(for: service) { result in
                    switch result {
                    case .success(let items):
                        self.saveToCache(service: service, items: items)
                    case .failure(let error):
                        print("[FlixPatrolService] Failed to fetch \(service): \(error)")
                    }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            completion()
        }
    }
} 
