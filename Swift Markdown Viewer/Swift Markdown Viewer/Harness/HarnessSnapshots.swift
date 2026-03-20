import CoreGraphics
import Foundation

struct VisibleBlockSnapshot: Codable {
    let id: String
    let kind: String
    let text: String
}

struct SidebarSnapshot: Codable {
    let selectedNode: String?
}

struct NavigationHistorySnapshot: Codable {
    let backCount: Int
    let forwardCount: Int
}

struct ViewportSnapshot: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct HarnessStateSnapshot: Codable {
    let platform: String
    let deviceClass: String
    let workspaceRoot: String
    let selectedFile: String?
    let history: NavigationHistorySnapshot
    let viewport: ViewportSnapshot
    let visibleBlocks: [VisibleBlockSnapshot]
    let sidebar: SidebarSnapshot
}

struct HarnessPerformanceSnapshot: Codable {
    let platform: String
    let deviceClass: String
    let launchTime: Double
    let readyTime: Double
    let visibleBlockCount: Int
    let activeAnimatedMediaCount: Int
    let activeVideoPlayerCount: Int
}
