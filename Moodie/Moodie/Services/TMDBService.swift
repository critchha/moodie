import Foundation

struct TMDBTrendingTitle: Identifiable, Codable {
    let id: Int
    let title: String
    let type: String // "movie" or "tv"
    let runtime: Int?
    let genres: [String]
    let overview: String
    let streamingPlatforms: [String]
    var isInTheaters: Bool?
    let posterURL: String?
}

// MARK: - TMDB API Response Structs (top-level)
struct TrendingResponse: Codable, @unchecked Sendable {
    let results: [TrendingSummary]
}
struct TrendingSummary: Codable, @unchecked Sendable {
    let id: Int
    let title: String? // for movies
    let name: String? // for tv
    let genre_ids: [Int]
    let overview: String
}
struct Detail: Codable, @unchecked Sendable {
    let id: Int
    let title: String? // for movies
    let name: String? // for tv
    let runtime: Int? // for movies
    let episode_run_time: [Int]? // for tv
    let genres: [Genre]
    let overview: String
    let poster_path: String?
    struct Genre: Codable, @unchecked Sendable { let name: String }
}
struct ProvidersResponse: Codable, @unchecked Sendable {
    let results: [String: Region]
    struct Region: Codable, @unchecked Sendable {
        let flatrate: [Provider]?
        struct Provider: Codable, @unchecked Sendable { let provider_name: String }
    }
}

class TMDBService {
    static let shared = TMDBService()
    private init() {}
    
    private let apiKey = "02987a3ea5129247e42e01418c1002cc"
    private let bearerToken = "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIwMjk4N2EzZWE1MTI5MjQ3ZTQyZTAxNDE4YzEwMDJjYyIsIm5iZiI6MTc0OTkzMzY1OC43MjcsInN1YiI6IjY4NGRkZTVhNGVmNGM0YmVlNjI5NGEyMyIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.sdCQPmf_EOhh_nVLOzz_ytUlN8gngnKHEWIVHO7_uBo"
    private let baseURL = "https://api.themoviedb.org/3"
    private let region = "US"
    private let language = "en-US"
    
    func fetchTrending(completion: @escaping (Result<[TMDBTrendingTitle], Error>) -> Void) {
        let group = DispatchGroup()
        var trending: [TMDBTrendingTitle] = []
        var errors: [Error] = []
        // Fetch trending movies
        group.enter()
        fetchTrendingType(type: "movie") { result in
            switch result {
            case .success(let movies): trending.append(contentsOf: movies)
            case .failure(let error): errors.append(error)
            }
            group.leave()
        }
        // Fetch trending TV shows
        group.enter()
        fetchTrendingType(type: "tv") { result in
            switch result {
            case .success(let shows): trending.append(contentsOf: shows)
            case .failure(let error): errors.append(error)
            }
            group.leave()
        }
        group.notify(queue: .main) {
            if !trending.isEmpty {
                completion(.success(trending))
            } else if let error = errors.first {
                completion(.failure(error))
            } else {
                completion(.success([]))
            }
        }
    }
    
    private func fetchTrendingType(type: String, completion: @escaping (Result<[TMDBTrendingTitle], Error>) -> Void) {
        let urlString = "\(baseURL)/trending/\(type)/week?language=\(language)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "TMDBService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("[TMDBService] fetchTrendingType(\(type)) HTTP status: \(httpResponse.statusCode)")
            }
            if let error = error {
                print("[TMDBService] fetchTrendingType(\(type)) network error: \(error)")
                completion(.failure(error))
                return
            }
            guard let data = data else {
                print("[TMDBService] fetchTrendingType(\(type)) no data")
                completion(.failure(NSError(domain: "TMDBService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            // Log raw JSON
            if let rawString = String(data: data, encoding: .utf8) {
                print("[TMDBService] fetchTrendingType(\(type)) raw JSON: \(rawString.prefix(500))...")
            }
            do {
                let decoder = JSONDecoder()
                let trendingResponse = try decoder.decode(TrendingResponse.self, from: data)
                print("[TMDBService] fetchTrendingType(\(type)) parsed results count: \(trendingResponse.results.count)")
                if !trendingResponse.results.isEmpty {
                    print("[TMDBService] fetchTrendingType(\(type)) first result: \(trendingResponse.results[0])")
                }
                // Map to TMDBTrendingTitle
                let mapped = trendingResponse.results.map { TMDBTrendingTitle(from: $0) }
                print("[TMDBService] fetchTrendingType(\(type)) mapped TMDBTrendingTitle count: \(mapped.count)")
                if !mapped.isEmpty {
                    print("[TMDBService] fetchTrendingType(\(type)) first mapped: \(mapped[0])")
                }
                // If you filter mapped, log after filtering
                let filtered = mapped.filter { !$0.title.isEmpty }
                print("[TMDBService] fetchTrendingType(\(type)) filtered TMDBTrendingTitle count: \(filtered.count)")
                if !filtered.isEmpty {
                    print("[TMDBService] fetchTrendingType(\(type)) first filtered: \(filtered[0])")
                }
                completion(.success(filtered))
            } catch {
                print("[TMDBService] fetchTrendingType(\(type)) JSON decode error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func fetchDetails(for id: Int, type: String, completion: @escaping (TMDBTrendingTitle?) -> Void) {
        let urlString = "\(baseURL)/\(type)/\(id)?language=\(language)"
        guard let url = URL(string: urlString) else { completion(nil); return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        print("[TMDBService] fetchDetails called for id=\(id), type=\(type)")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("[TMDBService] fetchDetails id=\(id) HTTP status: \(httpResponse.statusCode)")
            }
            if let error = error {
                print("[TMDBService] fetchDetails id=\(id) network error: \(error)")
                completion(nil)
                return
            }
            guard let data = data else { completion(nil); return }
            do {
                let detail = try JSONDecoder().decode(TMDBTrendingTitle.self, from: data)
                print("[TMDBService] fetchDetails id=\(id) decoded: \(detail)")
                completion(detail)
            } catch {
                print("[TMDBService] fetchDetails id=\(id) decode error: \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    private func fetchProviders(for id: Int, type: String, completion: @escaping ([String]) -> Void) {
        let urlString = "\(baseURL)/\(type)/\(id)/watch/providers"
        guard let url = URL(string: urlString) else { completion([]); return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        print("[TMDBService] fetchProviders called for id=\(id), type=\(type)")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("[TMDBService] fetchProviders id=\(id) HTTP status: \(httpResponse.statusCode)")
            }
            if let error = error {
                print("[TMDBService] fetchProviders id=\(id) network error: \(error)")
                completion([])
                return
            }
            guard let data = data else { completion([]); return }
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                print("[TMDBService] fetchProviders id=\(id) raw JSON: \(json)")
                let providersResponse = try JSONDecoder().decode(ProvidersResponse.self, from: data)
                let region = providersResponse.results[self.region]
                let providers = region?.flatrate?.map { $0.provider_name } ?? []
                completion(providers)
            } catch {
                print("[TMDBService] fetchProviders id=\(id) decode error: \(error)")
                completion([])
            }
        }.resume()
    }
    
    // New function to check if a movie is in theaters
    private func isMovieInTheaters(id: Int, completion: @escaping (Bool) -> Void) {
        let urlString = "\(baseURL)/movie/\(id)/release_dates"
        guard let url = URL(string: urlString) else { completion(false); return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { completion(false); return }
            struct ReleaseDatesResponse: Codable, @unchecked Sendable {
                let results: [Region]
                struct Region: Codable, @unchecked Sendable {
                    let iso_3166_1: String
                    let release_dates: [Release]
                    struct Release: Codable, @unchecked Sendable {
                        let type: Int
                        let release_date: String
                    }
                }
            }
            if let resp = try? JSONDecoder().decode(ReleaseDatesResponse.self, from: data) {
                let us = resp.results.first(where: { $0.iso_3166_1 == "US" })
                let now = Date()
                let formatter = ISO8601DateFormatter()
                if let releases = us?.release_dates {
                    for r in releases where r.type == 3 || r.type == 4 {
                        if let date = formatter.date(from: r.release_date) {
                            // Consider "in theaters" if released within last 90 days
                            if let diff = Calendar.current.dateComponents([.day], from: date, to: now).day, diff >= 0 && diff <= 90 {
                                completion(true)
                                return
                            }
                        }
                    }
                }
            }
            completion(false)
        }.resume()
    }
}

// MARK: - TMDBTrendingTitle Mapping Extension
extension TMDBTrendingTitle {
    init(from summary: TrendingSummary) {
        self.id = summary.id
        self.title = summary.title ?? summary.name ?? ""
        self.type = summary.title != nil ? "movie" : "tv"
        self.runtime = nil
        self.genres = [] // genre_ids could be mapped to names if you have a lookup
        self.overview = summary.overview
        self.streamingPlatforms = []
        self.isInTheaters = nil
        self.posterURL = nil
    }
} 