import Foundation

class FlixPatrolService {
    static let shared = FlixPatrolService()
    private init() {}
    
    // Supported streaming services
    let supportedServices = ["Netflix", "Hulu", "HBO", "Paramount+", "Apple TV+", "Disney+"]
    let apiKey = "aku_80kB3PlONbeWiHX60xVfZLm4"
    let country = "us"
    let cacheDirectory: URL = {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("flixpatrol_cache")
    }()
    let cacheExpiry: TimeInterval = 60 * 60 * 24 // 24 hours
    
    // MARK: - Fetch Top 100 for a service
    func fetchTop100(for service: String, completion: @escaping (Result<[MediaItem], Error>) -> Void) {
        // Map service to FlixPatrol API slug if needed
        let serviceSlug = service.lowercased().replacingOccurrences(of: " ", with: "-")
        let urlString = "https://api.flixpatrol.com/v1/us/\(serviceSlug)/top100?apikey=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "FlixPatrolService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "FlixPatrolService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            do {
                let items = try self.parseMediaItems(from: data, service: service)
                completion(.success(items))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    // MARK: - Parse JSON to [MediaItem]
    private func parseMediaItems(from data: Data, service: String) throws -> [MediaItem] {
        // TODO: Adjust this to match FlixPatrol's actual JSON structure
        struct FlixPatrolItem: Decodable {
            let id: String
            let title: String
            let year: Int?
            let type: String
            let genres: [String]?
            let directors: [String]?
            let cast: [String]?
            let duration: Int?
            let summary: String?
            let posterURL: String?
            let seriesTitle: String?
        }
        let decoder = JSONDecoder()
        let rawItems = try decoder.decode([FlixPatrolItem].self, from: data)
        let items: [MediaItem] = rawItems.map { raw in
            MediaItem(
                id: raw.id,
                title: raw.title,
                year: raw.year,
                type: raw.type,
                genres: raw.genres ?? [],
                directors: raw.directors ?? [],
                cast: raw.cast ?? [],
                duration: raw.duration ?? 0,
                viewCount: 0,
                summary: raw.summary ?? "",
                posterURL: raw.posterURL,
                seriesTitle: raw.seriesTitle,
                lastRecommended: nil,
                platforms: [service],
                country: country
            )
        }
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
        } catch {
            print("[FlixPatrolService] Failed to save cache for \(service): \(error)")
        }
    }
    
    func loadFromCache(service: String) -> [MediaItem] {
        let url = cacheFileURL(for: service)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let items = try JSONDecoder().decode([MediaItem].self, from: data)
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