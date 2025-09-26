import SwiftUI
import HealthKit
import Combine

struct ContentView: View {
    @StateObject private var healthManager = HealthKitManager()
    @State private var isLoading = false
    @State private var lastSyncTime: String = "Mai"
    @State private var statusMessage: String = "Pronto per sincronizzare"
    @State private var dailySummary: DailySummary?
    @State private var isLoadingSummary = false
    
    var body: some View {
        NavigationView {
            RefreshableScrollView(onRefresh: {
                syncData()
            }) {
                LazyVStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("HealthKit Sync")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Sincronizzando...")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    // Card HealthKit Data
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Passi oggi:")
                            Spacer()
                            Text("\(healthManager.todaySteps)")
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Calorie giornaliere:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(String(format: "%.0f kcal", healthManager.todayTotalCalories))
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            
                            // Barra visuale calorie
                            GeometryReader { geometry in
                                let totalCalories = max(healthManager.todayTotalCalories, 1)
                                let activeWidth = (healthManager.todayCalories / totalCalories) * geometry.size.width
                                let restingWidth = (healthManager.todayRestingCalories / totalCalories) * geometry.size.width
                                
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(LinearGradient(
                                            colors: [Color.orange, Color.red.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(width: activeWidth)
                                    
                                    Rectangle()
                                        .fill(LinearGradient(
                                            colors: [Color.blue.opacity(0.7), Color.blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(width: restingWidth)
                                }
                                .frame(height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .frame(height: 20)
                            
                            // Legenda
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 8, height: 8)
                                    Text("Attive: \(String(format: "%.0f", healthManager.todayCalories))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 8, height: 8)
                                    Text("Riposo: \(String(format: "%.0f", healthManager.todayRestingCalories))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    if !healthManager.isAuthorized {
                        Text("Autorizza HealthKit per continuare")
                            .foregroundColor(.orange)
                            .font(.caption)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Daily Summary Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Riepilogo Giornaliero")
                                .font(.headline)
                            Spacer()
                            Button(action: loadDailySummary) {
                                HStack(spacing: 4) {
                                    if isLoadingSummary {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption)
                                    }
                                }
                            }
                            .disabled(isLoadingSummary)
                        }
                        
                        if let summary = dailySummary {
                            VStack(spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Passi")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("\(summary.activitySteps)")
                                            .font(.headline)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Calorie Bruciate")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(String(format: "%.0f", summary.activityCaloriesOut))
                                            .font(.headline)
                                    }
                                }
                                
                                Divider()
                                
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Pasti")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("\(summary.meals)")
                                            .font(.headline)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Calorie Cibo")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("\(summary.calories)")
                                            .font(.headline)
                                    }
                                }
                                
                                Divider()
                                
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Deficit Calorico")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("\(summary.caloriesDeficit)")
                                            .font(.headline)
                                            .foregroundColor(summary.caloriesDeficit > 0 ? .green : .red)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Completamento")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("\(summary.caloriesReplenishedPercent)%")
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        } else {
                            Text(isLoadingSummary ? "Caricamento..." : "Premi il pulsante per caricare i dati")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationBarHidden(true)
            .overlay(
                VStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        // Info ultimo sync
                        VStack(spacing: 2) {
                            Text("Ultimo sync: \(lastSyncTime)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            Text(statusMessage)
                                .font(.caption2)
                                .foregroundColor(statusMessage.contains("✅") ? .green : .blue)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Bottone sync più piccolo
                        Button(action: syncData) {
                            HStack(spacing: 6) {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                                Text(isLoading ? "Sincronizzando..." : "SYNC NOW")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .disabled(isLoading || !healthManager.isAuthorized)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 34)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea(.container, edges: .bottom)
                    )
                }
            )
        }
        .onAppear {
            healthManager.requestAuthorization()
            loadDailySummary()
        }
    }
    
    // Rimuovi la funzione performSync che non serve più
    
    private func syncData() {
        isLoading = true
        statusMessage = "Sincronizzazione in corso..."
        
        healthManager.fetchTodayData { success in
            DispatchQueue.main.async {
                if success {
                    // Invia dati via GraphQL
                    sendToGraphQL()
                } else {
                    isLoading = false
                    statusMessage = "❌ Errore lettura HealthKit"
                }
            }
        }
    }
    
    private func sendToGraphQL() {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: now)
        
        // Crea l'input per la mutation
        let activityInput: [String: Any] = [
            "ts": timestamp,
            "steps": healthManager.todaySteps,
            "caloriesOut": healthManager.todayTotalCalories, // Usiamo il totale
            "source": "APPLE_HEALTH"
        ]
        
        let mutation = """
        mutation IngestActivityEvents($input: [ActivityMinuteInput!]!, $userId: String!) {
            ingestActivityEvents(input: $input, userId: $userId) {
                accepted
                rejected {
                    reason
                }
            }
        }
        """
        
        let variables: [String: Any] = [
            "input": [activityInput],
            "userId": "000001"
        ]
        
        let requestBody: [String: Any] = [
            "query": mutation,
            "variables": variables
        ]
        
        guard let url = URL(string: "https://nutrifit-backend-api.onrender.com/graphql") else {
            DispatchQueue.main.async {
                isLoading = false
                statusMessage = "❌ URL non valido"
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            // DEBUG: Stampa i dati che stiamo inviando
            print("🚀 Invio dati a GraphQL:")
            if let jsonData = request.httpBody,
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
            
        } catch {
            DispatchQueue.main.async {
                isLoading = false
                statusMessage = "❌ Errore serializzazione"
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                // DEBUG: Stampa la risposta
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Risposta server:")
                    print(responseString)
                }
                
                if let error = error {
                    print("❌ Errore rete: \(error)")
                    statusMessage = "❌ Errore rete: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📊 Status code: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 200 {
                        statusMessage = "✅ Sincronizzato!"
                        lastSyncTime = DateFormatter.timeFormatter.string(from: Date())
                        // Ricarica il summary dopo il sync
                        loadDailySummary()
                    } else {
                        statusMessage = "❌ Server error: \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
    
    private func loadDailySummary() {
        isLoadingSummary = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        
        let query = """
        query DailySummary($userId: String!, $date: String!) {
            dailySummary(userId: $userId, date: $date) {
                calories
                userId
                carbs
                date
                fat
                meals
                protein
                sodium
                sugar
                fiber
                caloriesDeficit
                activityEvents
                activityCaloriesOut
                caloriesReplenishedPercent
                activitySteps
            }
        }
        """
        
        let variables: [String: Any] = [
            "userId": "000001",
            "date": todayString
        ]
        
        let requestBody: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        guard let url = URL(string: "https://nutrifit-backend-api.onrender.com/graphql") else {
            DispatchQueue.main.async {
                isLoadingSummary = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            DispatchQueue.main.async {
                isLoadingSummary = false
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoadingSummary = false
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataDict = json["data"] as? [String: Any],
                      let summaryDict = dataDict["dailySummary"] as? [String: Any] else {
                    print("❌ Errore parsing dailySummary")
                    return
                }
                
                // Parse della risposta
                dailySummary = DailySummary(
                    calories: summaryDict["calories"] as? Int ?? 0,
                    userId: summaryDict["userId"] as? String ?? "",
                    carbs: summaryDict["carbs"] as? Double ?? 0.0,
                    date: summaryDict["date"] as? String ?? "",
                    fat: summaryDict["fat"] as? Double ?? 0.0,
                    meals: summaryDict["meals"] as? Int ?? 0,
                    protein: summaryDict["protein"] as? Double ?? 0.0,
                    sodium: summaryDict["sodium"] as? Double ?? 0.0,
                    sugar: summaryDict["sugar"] as? Double ?? 0.0,
                    fiber: summaryDict["fiber"] as? Double ?? 0.0,
                    caloriesDeficit: summaryDict["caloriesDeficit"] as? Int ?? 0,
                    activityEvents: summaryDict["activityEvents"] as? Int ?? 0,
                    activityCaloriesOut: summaryDict["activityCaloriesOut"] as? Double ?? 0.0,
                    caloriesReplenishedPercent: summaryDict["caloriesReplenishedPercent"] as? Int ?? 0,
                    activitySteps: summaryDict["activitySteps"] as? Int ?? 0
                )
            }
        }.resume()
    }
}

// Struct per il Daily Summary
struct DailySummary {
    let calories: Int
    let userId: String
    let carbs: Double
    let date: String
    let fat: Double
    let meals: Int
    let protein: Double
    let sodium: Double
    let sugar: Double
    let fiber: Double
    let caloriesDeficit: Int
    let activityEvents: Int
    let activityCaloriesOut: Double
    let caloriesReplenishedPercent: Int
    let activitySteps: Int
}

class HealthKitManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var todaySteps = 0
    @Published var todayCalories: Double = 0.0
    @Published var todayRestingCalories: Double = 0.0
    @Published var todayTotalCalories: Double = 0.0
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let activeCalorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let restingCalorieType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!
        
        let readTypes: Set<HKObjectType> = [stepType, activeCalorieType, restingCalorieType]
        
        healthStore.requestAuthorization(toShare: [], read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
            }
        }
    }
    
    func fetchTodayData(completion: @escaping (Bool) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        // Fetch steps
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let stepQuery = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            
            guard let result = result, let sum = result.sumQuantity() else {
                completion(false)
                return
            }
            
            DispatchQueue.main.async {
                self?.todaySteps = Int(sum.doubleValue(for: HKUnit.count()))
            }
            
            // Fetch active calories
            let activeCalorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let activeCalorieQuery = HKStatisticsQuery(quantityType: activeCalorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
                
                DispatchQueue.main.async {
                    if let result = result, let sum = result.sumQuantity() {
                        self?.todayCalories = sum.doubleValue(for: HKUnit.kilocalorie())
                    }
                }
                
                // Fetch resting calories
                let restingCalorieType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!
                let restingCalorieQuery = HKStatisticsQuery(quantityType: restingCalorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
                    
                    DispatchQueue.main.async {
                        if let result = result, let sum = result.sumQuantity() {
                            self?.todayRestingCalories = sum.doubleValue(for: HKUnit.kilocalorie())
                        }
                        
                        // Calcola totale
                        if let strongSelf = self {
                            strongSelf.todayTotalCalories = strongSelf.todayCalories + strongSelf.todayRestingCalories
                        }
                        
                        completion(true)
                    }
                }
                
                self?.healthStore.execute(restingCalorieQuery)
            }
            
            self?.healthStore.execute(activeCalorieQuery)
        }
        
        healthStore.execute(stepQuery)
    }
}

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

// Pull-to-refresh con DragGesture moderno
struct RefreshableScrollView<Content: View>: View {
    let onRefresh: () -> Void
    let content: () -> Content
    
    @State private var isRefreshing = false
    @State private var dragOffset: CGFloat = 0
    
    private let refreshThreshold: CGFloat = 80
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Pull indicator
                HStack {
                    Spacer()
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else if dragOffset > 30 {
                        VStack(spacing: 4) {
                            Image(systemName: dragOffset > refreshThreshold ? "arrow.down.circle.fill" : "arrow.down.circle")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .rotationEffect(.degrees(dragOffset > refreshThreshold ? 180 : 0))
                            
                            Text(dragOffset > refreshThreshold ? "Rilascia per aggiornare" : "Trascina per aggiornare")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .frame(height: max(0, dragOffset))
                .opacity(dragOffset > 20 ? 1 : 0)
                
                content()
                    .offset(y: isRefreshing ? 60 : 0)
            }
        }
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if !isRefreshing && value.translation.height > 0 {
                        dragOffset = min(value.translation.height, 120)
                    }
                }
                .onEnded { value in
                    if !isRefreshing && dragOffset > refreshThreshold {
                        triggerRefresh()
                    } else {
                        withAnimation(.easeOut(duration: 0.3)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
    
    private func triggerRefresh() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isRefreshing = true
            dragOffset = 60
        }
        
        // Chiama il refresh
        onRefresh()
        
        // Reset dopo un delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                isRefreshing = false
                dragOffset = 0
            }
        }
    }
}
