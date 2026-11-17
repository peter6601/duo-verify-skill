import UIKit

final class ProbeVC: UIViewController {
    let label = UILabel()
    var hingeDesc = "none"
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemYellow
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        let safe = UIView(); safe.backgroundColor = .systemTeal; safe.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(safe); view.addSubview(label)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            safe.leadingAnchor.constraint(equalTo: g.leadingAnchor), safe.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            safe.topAnchor.constraint(equalTo: g.topAnchor), safe.bottomAnchor.constraint(equalTo: g.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 8), label.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: g.centerYAnchor)])
        let i = UIHingeInteraction { [weak self] _, update in
            guard let self else { return }
            if let h = update.hinge {
                let s: String
                switch h.status { case .closed: s = "closed"; case .partiallyOpen: s = "partiallyOpen"; case .fullyOpen: s = "fullyOpen"; default: s = "unknown" }
                self.hingeDesc = "\(s) angle=\(String(format: "%.1f", h.angle * 180 / .pi))deg"
            } else { self.hingeDesc = "nil" }
            self.report(event: "hinge")
        }
        view.addInteraction(i)
    }
    override func viewSafeAreaInsetsDidChange() { super.viewSafeAreaInsetsDidChange(); report(event: "safeArea") }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); report(event: "layout") }
    func report(event: String) {
        let ins = view.safeAreaInsets
        let ws = view.window?.windowScene
        let screen = ws?.screen
        let o: String = { switch ws?.effectiveGeometry.interfaceOrientation { case .portrait: "portrait"; case .portraitUpsideDown: "upsideDown"; case .landscapeLeft: "landscapeLeft"; case .landscapeRight: "landscapeRight"; default: "unknown" } }()
        let text = """
        event=\(event)
        hinge=\(hingeDesc)
        screen=\(screen.map { "\(Int($0.bounds.width))x\(Int($0.bounds.height))@\(Int($0.scale))x" } ?? "nil")
        view=\(Int(view.bounds.width))x\(Int(view.bounds.height))
        orientation=\(o)
        safe top=\(ins.top) left=\(ins.left) bottom=\(ins.bottom) right=\(ins.right)
        """
        label.text = text
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("probe.log")
        let line = ISO8601DateFormatter().string(from: Date()) + " " + text.replacingOccurrences(of: "\n", with: " | ") + "\n"
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close() }
        else { try? line.write(to: url, atomically: true, encoding: .utf8) }
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws); w.rootViewController = ProbeVC(); w.makeKeyAndVisible(); window = w
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ a: UIApplication, configurationForConnecting s: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: nil, sessionRole: s.role); c.delegateClass = SceneDelegate.self; return c
    }
}
