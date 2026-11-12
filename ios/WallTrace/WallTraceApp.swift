import UIKit
import ARKit
import SceneKit
import simd

struct StrokeRecord: Codable {
    let anchorID: String
    var points: [[Float]]
    let colorHex: String
}

struct WallTraceDocument: Codable {
    var strokes: [StrokeRecord] = []
}

final class WallTraceViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    private let sceneView = ARSCNView(frame: .zero)
    private let statusLabel = UILabel()
    private let drawButton = UIButton(type: .system)
    private var isDrawing = true
    private var document = WallTraceDocument()
    private var activeStrokeIndex: Int?
    private var activeAnchor: ARAnchor?
    private var worldMapURL: URL { documentsURL.appendingPathComponent("walltrace-worldmap.data") }
    private var documentURL: URL { documentsURL.appendingPathComponent("walltrace-strokes.json") }
    private var documentsURL: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupScene()
        setupControls()
        loadDocument()
        runSession(restoring: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    private func setupScene() {
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        view.addSubview(sceneView)
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDraw(_:)))
        pan.maximumNumberOfTouches = 1
        sceneView.addGestureRecognizer(pan)
    }

    private func setupControls() {
        let panel = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.layer.cornerRadius = 16
        panel.clipsToBounds = true
        view.addSubview(panel)

        statusLabel.text = "Наведите камеру на стену и медленно перемещайте её для сканирования"
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        drawButton.setTitle("Рисование: ВКЛ", for: .normal)
        drawButton.addTarget(self, action: #selector(toggleDrawing), for: .touchUpInside)
        let saveButton = makeButton("Сохранить", #selector(saveAll))
        let restoreButton = makeButton("Восстановить", #selector(restoreMap))
        let clearButton = makeButton("Очистить", #selector(clearAll))
        let row = UIStackView(arrangedSubviews: [drawButton, saveButton, restoreButton, clearButton])
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        [drawButton, saveButton, restoreButton, clearButton].forEach {
            $0.setTitleColor(.white, for: .normal)
            $0.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
            $0.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.72)
            $0.layer.cornerRadius = 9
        }
        panel.contentView.addSubview(statusLabel)
        panel.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            panel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            panel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            statusLabel.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            row.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -8),
            row.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -8),
            row.heightAnchor.constraint(equalToConstant: 42)
        ])
    }

    private func makeButton(_ title: String, _ action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func runSession(restoring: Bool) {
        guard ARWorldTrackingConfiguration.isSupported else {
            statusLabel.text = "Этот iPhone не поддерживает ARWorldTracking."
            return
        }
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical, .horizontal]
        config.environmentTexturing = .automatic
        if restoring, let data = try? Data(contentsOf: worldMapURL),
           let map = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
            config.initialWorldMap = map
            sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            statusLabel.text = "Восстанавливаем сохранённое пространство. Медленно осмотрите стену."
        } else {
            sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            statusLabel.text = "Сканируйте стену: медленно двигайте iPhone, пока ARKit изучает поверхность."
        }
    }

    @objc private func toggleDrawing() {
        isDrawing.toggle()
        drawButton.setTitle(isDrawing ? "Рисование: ВКЛ" : "Рисование: ВЫКЛ", for: .normal)
        statusLabel.text = isDrawing ? "Проведите пальцем по найденной вертикальной поверхности." : "Режим просмотра. Перемещайте телефон вокруг стены."
    }

    @objc private func handleDraw(_ gesture: UIPanGestureRecognizer) {
        guard isDrawing else { return }
        let point = gesture.location(in: sceneView)
        guard let hit = raycastWall(at: point) else {
            if gesture.state == .began { statusLabel.text = "Стена пока не распознана. Медленно осмотрите её камерой." }
            if gesture.state == .ended || gesture.state == .cancelled { finishStroke() }
            return
        }
        switch gesture.state {
        case .began:
            beginStroke(at: hit.worldTransform)
        case .changed:
            appendPoint(hit.worldTransform)
        case .ended, .cancelled, .failed:
            appendPoint(hit.worldTransform)
            finishStroke()
        default: break
        }
    }

    private func raycastWall(at point: CGPoint) -> ARRaycastResult? {
        guard let query = sceneView.raycastQuery(from: point, allowing: .existingPlaneGeometry, alignment: .vertical) else { return nil }
        return sceneView.session.raycast(query).first
    }

    private func beginStroke(at transform: simd_float4x4) {
        finishStroke()
        let anchor = ARAnchor(name: UUID().uuidString, transform: transform)
        activeAnchor = anchor
        document.strokes.append(StrokeRecord(anchorID: anchor.identifier.uuidString, points: [[0, 0, 0]], colorHex: "#FF3B30"))
        activeStrokeIndex = document.strokes.count - 1
        sceneView.session.add(anchor: anchor)
    }

    private func appendPoint(_ worldTransform: simd_float4x4) {
        guard let anchor = activeAnchor, let index = activeStrokeIndex else { return }
        let worldPoint = SIMD4<Float>(worldTransform.columns.3.x, worldTransform.columns.3.y, worldTransform.columns.3.z, 1)
        let local = simd_inverse(anchor.transform) * worldPoint
        let p = [local.x, local.y, local.z]
        if let last = document.strokes[index].points.last {
            let dx = p[0] - last[0], dy = p[1] - last[1], dz = p[2] - last[2]
            if dx*dx + dy*dy + dz*dz < 0.000004 { return }
        }
        document.strokes[index].points.append(p)
        redraw(anchorID: anchor.identifier.uuidString)
    }

    private func finishStroke() {
        activeStrokeIndex = nil
        activeAnchor = nil
        persistDocument()
    }

    private func redraw(anchorID: String) {
        guard let record = document.strokes.first(where: { $0.anchorID == anchorID }),
              let anchor = sceneView.session.currentFrame?.anchors.first(where: { $0.identifier.uuidString == anchorID }),
              let node = sceneView.node(for: anchor) else { return }
        node.childNodes.forEach { $0.removeFromParentNode() }
        let points = record.points.map { SIMD3<Float>($0[0], $0[1], $0[2]) }
        guard points.count > 1 else { return }
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let delta = b - a
            let length = simd_length(delta)
            guard length > 0.001 else { continue }
            let cylinder = SCNCylinder(radius: 0.006, height: CGFloat(length))
            cylinder.radialSegmentCount = 8
            cylinder.firstMaterial?.diffuse.contents = UIColor.systemRed
            cylinder.firstMaterial?.lightingModel = .constant
            let segment = SCNNode(geometry: cylinder)
            segment.simdPosition = (a + b) / 2
            segment.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(delta))
            node.addChildNode(segment)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async { self.redraw(anchorID: anchor.identifier.uuidString) }
    }

    @objc private func saveAll() {
        finishStroke()
        guard let frame = sceneView.session.currentFrame else {
            statusLabel.text = "Пока нет AR-сессии для сохранения."
            return
        }
        frame.session.getCurrentWorldMap { [weak self] map, error in
            guard let self = self, let map = map, error == nil else {
                DispatchQueue.main.async { self?.statusLabel.text = "Не удалось сохранить карту. Ещё немного просканируйте стену." }
                return
            }
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                try data.write(to: self.worldMapURL, options: .atomic)
                self.persistDocument()
                DispatchQueue.main.async { self.statusLabel.text = "Карта пространства и кабельные трассы сохранены на iPhone." }
            } catch {
                DispatchQueue.main.async { self.statusLabel.text = "Ошибка сохранения: \(error.localizedDescription)" }
            }
        }
    }

    @objc private func restoreMap() {
        loadDocument()
        runSession(restoring: true)
    }

    @objc private func clearAll() {
        document = WallTraceDocument()
        persistDocument()
        sceneView.session.run(ARWorldTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
        statusLabel.text = "Трассы удалены. Просканируйте стену заново."
    }

    private func persistDocument() {
        guard let data = try? JSONEncoder().encode(document) else { return }
        try? data.write(to: documentURL, options: .atomic)
    }

    private func loadDocument() {
        guard let data = try? Data(contentsOf: documentURL),
              let decoded = try? JSONDecoder().decode(WallTraceDocument.self, from: data) else { return }
        document = decoded
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.statusLabel.text = "ARKit: \(error.localizedDescription)" }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async { self.statusLabel.text = "AR-сессия прервана. Вернитесь к приложению и восстановите карту." }
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = WallTraceViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
