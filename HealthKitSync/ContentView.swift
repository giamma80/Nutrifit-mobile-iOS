import SwiftUI
import HealthKit
import Combine
import VisionKit
import AVFoundation
internal import Vision

// Observable class per gestire il barcode scanner
class BarcodeManager: ObservableObject {
    @Published var currentBarcode: String = ""
    @Published var showingBarcodeScanner = false
    @Published var showingQuantityInput = false
    
    func setBarcodeAndShowInput(_ barcode: String) {
        currentBarcode = barcode
        showingBarcodeScanner = false
        showingQuantityInput = true
    }
    
    func reset() {
        currentBarcode = ""
        showingQuantityInput = false
    }
}

struct ContentView: View {
    @StateObject private var healthManager = HealthKitManager()
    @StateObject private var barcodeManager = BarcodeManager()
    @State private var isLoading = false
    @State private var lastSyncTime: String = "Mai"
    @State private var statusMessage: String = "Pronto per sincronizzare"
    @State private var dailySummary: DailySummary?
    @State private var isLoadingSummary = false
    
    // Stati per input quantità
    @State private var quantityInput: String = ""
    @State private var isLoggingMeal = false
    
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
                        
                        // Bottoni in riga
                        HStack(spacing: 12) {
                            // Bottone barcode scanner
                            Button(action: { barcodeManager.showingBarcodeScanner = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "barcode.viewfinder")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("SCAN")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            
                            // Bottone sync
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
        .sheet(isPresented: $barcodeManager.showingBarcodeScanner) {
            BarcodeScannerView { barcode in
                print("📱 Barcode ricevuto dalla camera: '\(barcode)'")
                barcodeManager.setBarcodeAndShowInput(barcode)
            }
        }
        .sheet(isPresented: $barcodeManager.showingQuantityInput) {
            QuantityInputView(
                barcode: barcodeManager.currentBarcode,
                quantity: $quantityInput,
                isLoading: $isLoggingMeal
            ) { quantity in
                print("💾 Salvando pasto con barcode: '\(barcodeManager.currentBarcode)' e quantità: \(quantity)")
                logMeal(barcode: barcodeManager.currentBarcode, quantity: quantity)
            }
        }
    }
    
    private func syncData() {
        isLoading = true
        statusMessage = "Sincronizzazione in corso..."
        
        healthManager.fetchTodayData { success in
            DispatchQueue.main.async {
                if success {
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
        
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = timestampFormatter.string(from: now)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.string(from: now)
        
        let healthInput: [String: Any] = [
            "timestamp": timestamp,
            "date": date,
            "steps": healthManager.todaySteps,
            "caloriesOut": healthManager.todayTotalCalories,
            "userId": "000001"
        ]
        
        let mutation = """
        mutation SyncHealthTotals($input: HealthTotalsInput!, $userId: String) {
            syncHealthTotals(input: $input, userId: $userId) {
                accepted
                duplicate
                reset
                delta {
                    stepsDelta
                    caloriesOutDelta
                    stepsTotal
                    caloriesOutTotal
                }
            }
        }
        """
        
        let variables: [String: Any] = [
            "input": healthInput,
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
            print("🚀 Invio dati:", String(data: request.httpBody!, encoding: .utf8) ?? "")
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
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Risposta server:", responseString)
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    statusMessage = "✅ Sincronizzato!"
                    lastSyncTime = DateFormatter.timeFormatter.string(from: Date())
                    loadDailySummary()
                } else {
                    statusMessage = "❌ Errore sync"
                }
            }
        }.resume()
    }
    
    private func logMeal(barcode: String, quantity: Double) {
        isLoggingMeal = true
        
        let now = Date()
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: now)
        
        let mealInput: [String: Any] = [
            "quantityG": quantity,
            "userId": "000001",
            "timestamp": timestamp,
            "barcode": barcode,
            "name": "Pasto scansionato"
        ]
        
        let mutation = """
        mutation LogMeal($input: LogMealInput!) {
            logMeal(input: $input) {
                carbs
                barcode
                name
                nutrientSnapshotJson
                calories
                fat
                fiber
                protein
                sodium
                sugar
            }
        }
        """
        
        let variables: [String: Any] = [
            "input": mealInput
        ]
        
        let requestBody: [String: Any] = [
            "query": mutation,
            "variables": variables
        ]
        
        guard let url = URL(string: "https://nutrifit-backend-api.onrender.com/graphql") else {
            DispatchQueue.main.async {
                isLoggingMeal = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("🍽️ Invio dati pasto:", String(data: request.httpBody!, encoding: .utf8) ?? "")
        } catch {
            DispatchQueue.main.async {
                isLoggingMeal = false
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoggingMeal = false
                barcodeManager.reset() // Reset tramite il manager
                quantityInput = ""
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Risposta pasto:", responseString)
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    loadDailySummary()
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
        
        onRefresh()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                isRefreshing = false
                dragOffset = 0
            }
        }
    }
}

// Vista per lo scanner di barcode con fallback AVFoundation
struct BarcodeScannerView: UIViewControllerRepresentable {
    let onBarcodeScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Forza l'uso di AVFoundation per evitare bug VisionKit
        print("🔧 Uso forzato di AVFoundation per maggiore stabilità")
        return createAVFoundationScanner(context: context)
        
        /* VisionKit temporaneamente disabilitato per bug iOS
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            print("🟢 VisionKit disponibile - uso DataScannerViewController")
            return createVisionKitScanner(context: context)
        } else {
            print("🟡 VisionKit non disponibile - fallback ad AVFoundation")
            return createAVFoundationScanner(context: context)
        }
        */
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeScanned: onBarcodeScanned)
    }
    
    private func createVisionKitScanner(context: Context) -> DataScannerViewController {
        let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
            .barcode(symbologies: [.ean8, .ean13, .code128, .qr, .pdf417])
        ]
        
        let scanner = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        
        scanner.delegate = context.coordinator
        return scanner
    }
    
    private func createAVFoundationScanner(context: Context) -> AVFoundationScannerViewController {
        return AVFoundationScannerViewController(onBarcodeScanned: onBarcodeScanned)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcodeScanned: (String) -> Void
        
        init(onBarcodeScanned: @escaping (String) -> Void) {
            self.onBarcodeScanned = onBarcodeScanned
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .barcode(let barcode):
                if let payloadString = barcode.payloadStringValue {
                    onBarcodeScanned(payloadString)
                }
            default:
                break
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                switch item {
                case .barcode(let barcode):
                    if let payloadString = barcode.payloadStringValue {
                        onBarcodeScanned(payloadString)
                        return
                    }
                default:
                    continue
                }
            }
        }
    }
}

// Fallback scanner con AVFoundation
class AVFoundationScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let onBarcodeScanned: (String) -> Void
    private var hasScanned = false
    
    init(onBarcodeScanned: @escaping (String) -> Void) {
        self.onBarcodeScanned = onBarcodeScanned
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScanner()
    }
    
    private func setupScanner() {
        view.backgroundColor = UIColor.black
        
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            showError("Camera non disponibile")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            showError("Errore accesso camera")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            showError("Impossibile configurare camera")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417, .qr, .code128]
        } else {
            showError("Impossibile configurare scanner")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        addOverlay()
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    private func addOverlay() {
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        let instructionLabel = UILabel()
        instructionLabel.text = "Inquadra un barcode"
        instructionLabel.textColor = .white
        instructionLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        instructionLabel.textAlignment = .center
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Chiudi", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        closeButton.backgroundColor = UIColor.systemRed
        closeButton.layer.cornerRadius = 8
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeScanner), for: .touchUpInside)
        
        overlayView.addSubview(instructionLabel)
        overlayView.addSubview(closeButton)
        view.addSubview(overlayView)
        
        NSLayoutConstraint.activate([
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            
            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            closeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            closeButton.widthAnchor.constraint(equalToConstant: 100),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func closeScanner() {
        cleanupCamera()
        dismiss(animated: true)
    }
    
    private func cleanupCamera() {
        hasScanned = true
        
        if captureSession?.isRunning == true {
            DispatchQueue.global(qos: .background).async {
                self.captureSession.stopRunning()
                
                DispatchQueue.main.async {
                    // Rimuovi tutti gli input e output
                    self.captureSession.inputs.forEach { input in
                        self.captureSession.removeInput(input)
                    }
                    self.captureSession.outputs.forEach { output in
                        self.captureSession.removeOutput(output)
                    }
                    
                    // Nullifica la sessione per liberare completamente le risorse
                    self.captureSession = nil
                    self.previewLayer?.removeFromSuperlayer()
                    self.previewLayer = nil
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Errore Scanner", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .background).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cleanupCamera()
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned else { return }
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            print("📸 Barcode scansionato dalla camera: '\(stringValue)'")
            hasScanned = true
            
            // Ferma immediatamente la camera per liberare risorse
            DispatchQueue.global(qos: .background).async {
                self.captureSession.stopRunning()
                
                // Pulizia completa della sessione
                DispatchQueue.main.async {
                    self.captureSession.inputs.forEach { input in
                        self.captureSession.removeInput(input)
                    }
                    self.captureSession.outputs.forEach { output in
                        self.captureSession.removeOutput(output)
                    }
                    
                    // Delay per stabilizzare iOS prima del callback
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("🔄 Invio barcode '\(stringValue)' alla callback")
                        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                        self.onBarcodeScanned(stringValue)
                    }
                }
            }
        }
    }
}

// Vista per input della quantità con informazioni prodotto
struct QuantityInputView: View {
    let barcode: String
    @Binding var quantity: String
    @Binding var isLoading: Bool
    let onConfirm: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var product: ProductInfo?
    @State private var isLoadingProduct = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Barcode Scansionato")
                        .font(.headline)
                    Text(barcode)
                        .font(.monospaced(.body)())
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Informazioni prodotto
                if isLoadingProduct {
                    VStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Caricamento informazioni prodotto...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else if let product = product {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Prodotto Trovato")
                                .font(.headline)
                                .foregroundColor(.green)
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let brand = product.brand, !brand.isEmpty {
                                Text(brand)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Informazioni nutrizionali per 100g
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Per 100g:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "flame")
                                        .foregroundColor(.orange)
                                        .frame(width: 16)
                                    Text("Calorie: \(product.calories ?? 0) kcal")
                                        .font(.caption)
                                }
                                
                                HStack {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .foregroundColor(.red)
                                        .frame(width: 16)
                                    Text("Proteine: \(String(format: "%.1f", product.protein ?? 0))g")
                                        .font(.caption)
                                }
                                
                                HStack {
                                    Image(systemName: "leaf")
                                        .foregroundColor(.green)
                                        .frame(width: 16)
                                    Text("Carboidrati: \(String(format: "%.1f", product.carbs ?? 0))g")
                                        .font(.caption)
                                }
                                
                                HStack {
                                    Image(systemName: "drop")
                                        .foregroundColor(.yellow)
                                        .frame(width: 16)
                                    Text("Grassi: \(String(format: "%.1f", product.fat ?? 0))g")
                                        .font(.caption)
                                }
                                
                                HStack {
                                    Image(systemName: "cube")
                                        .foregroundColor(.pink)
                                        .frame(width: 16)
                                    Text("Zuccheri: \(String(format: "%.1f", product.sugar ?? 0))g")
                                        .font(.caption)
                                }
                                
                                HStack {
                                    Image(systemName: "circle.grid.2x2")
                                        .foregroundColor(.brown)
                                        .frame(width: 16)
                                    Text("Fibre: \(String(format: "%.1f", product.fiber ?? 0))g")
                                        .font(.caption)
                                }
                                
                                HStack {
                                    Image(systemName: "saltshaker")
                                        .foregroundColor(.gray)
                                        .frame(width: 16)
                                    Text("Sodio: \(String(format: "%.1f", product.sodium ?? 0))g")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
                } else {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Prodotto non trovato nel database")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Verrà salvato solo il barcode")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quantità in grammi:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("es. 100", text: $quantity)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title2)
                }
                
                Button(action: {
                    if let quantityValue = Double(quantity), quantityValue > 0 {
                        onConfirm(quantityValue)
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Salvando..." : "Salva Pasto")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .disabled(quantity.isEmpty || Double(quantity) == nil || Double(quantity) ?? 0 <= 0 || isLoading)
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Aggiungi Pasto")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadProductInfo()
            }
        }
    }
    
    private func loadProductInfo() {
        isLoadingProduct = true
        
        print("🔍 Cercando prodotto con barcode: \(barcode)")
        
        let query = """
        query GetProduct($barcode: String!) {
            product(barcode: $barcode) {
                barcode
                brand
                calories
                carbs
                fat
                fiber
                name
                protein
                sodium
                sugar
            }
        }
        """
        
        let variables: [String: Any] = [
            "barcode": barcode
        ]
        
        let requestBody: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        guard let url = URL(string: "https://nutrifit-backend-api.onrender.com/graphql") else {
            print("❌ URL non valido")
            DispatchQueue.main.async {
                isLoadingProduct = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("🚀 Invio richiesta prodotto:", String(data: request.httpBody!, encoding: .utf8) ?? "")
        } catch {
            print("❌ Errore serializzazione query prodotto: \(error)")
            DispatchQueue.main.async {
                isLoadingProduct = false
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoadingProduct = false
                
                if let error = error {
                    print("❌ Errore rete query prodotto: \(error)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📊 Status code query prodotto: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("❌ Nessun dato ricevuto")
                    return
                }
                
                let responseString = String(data: data, encoding: .utf8) ?? ""
                print("📥 Risposta query prodotto: \(responseString)")
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataDict = json["data"] as? [String: Any] else {
                    print("❌ Errore parsing JSON risposta prodotto")
                    return
                }
                
                if let productDict = dataDict["product"] as? [String: Any] {
                    print("✅ Prodotto trovato: \(productDict)")
                    product = ProductInfo(
                        barcode: productDict["barcode"] as? String ?? "",
                        brand: productDict["brand"] as? String,
                        calories: productDict["calories"] as? Int,
                        carbs: productDict["carbs"] as? Double,
                        fat: productDict["fat"] as? Double,
                        fiber: productDict["fiber"] as? Double,
                        name: productDict["name"] as? String ?? "Prodotto sconosciuto",
                        protein: productDict["protein"] as? Double,
                        sodium: productDict["sodium"] as? Double,
                        sugar: productDict["sugar"] as? Double
                    )
                } else if dataDict["product"] == nil {
                    print("⚠️ Prodotto null - non trovato nel database")
                    // product rimane nil, mostrerà "prodotto non trovato"
                } else {
                    print("❌ Struttura risposta prodotto inaspettata")
                }
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

// Struct per le informazioni del prodotto
struct ProductInfo {
    let barcode: String
    let brand: String?
    let calories: Int?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let name: String
    let protein: Double?
    let sodium: Double?
    let sugar: Double?
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
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let stepQuery = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            
            guard let result = result, let sum = result.sumQuantity() else {
                completion(false)
                return
            }
            
            DispatchQueue.main.async {
                self?.todaySteps = Int(sum.doubleValue(for: HKUnit.count()))
            }
            
            let activeCalorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let activeCalorieQuery = HKStatisticsQuery(quantityType: activeCalorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
                
                DispatchQueue.main.async {
                    if let result = result, let sum = result.sumQuantity() {
                        self?.todayCalories = sum.doubleValue(for: HKUnit.kilocalorie())
                    }
                }
                
                let restingCalorieType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!
                let restingCalorieQuery = HKStatisticsQuery(quantityType: restingCalorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
                    
                    DispatchQueue.main.async {
                        if let result = result, let sum = result.sumQuantity() {
                            self?.todayRestingCalories = sum.doubleValue(for: HKUnit.kilocalorie())
                        }
                        
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
