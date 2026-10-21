//
//  MixerPresenter.swift
//  Capsule
//
//  Bridge between the SwiftUI views and the AppKit surfaces that host them.
//  A view can say "show the menu bar mixer on this app" without knowing whether
//  that means an NSPopover, a window, or nothing at all in a preview.
//

import Foundation

protocol MixerPresenting: AnyObject {
    /// Reveals the menu bar mixer.
    func presentMixer()
    /// Reveals the detached mixer window.
    func presentMixerWindow()
}

final class MixerPresenter {

    static let shared = MixerPresenter()

    private weak var presenter: MixerPresenting?
    private weak var manager: AudioManager?

    private init() {}

    func configure(manager: AudioManager, presenter: MixerPresenting) {
        self.manager = manager
        self.presenter = presenter
    }

    /// Opens the menu bar mixer scrolled and highlighted on `app`.
    ///
    /// The focus request is sent twice: once immediately (a mixer that is
    /// already on screen scrolls straight away) and once on the next run loop
    /// tick, after the popover has been put on screen, so a freshly created
    /// scroll view still lands on the right row.
    func showMixer(focusing app: AudioApp? = nil) {
        reveal(app: app, present: { [weak self] in self?.presenter?.presentMixer() })
    }

    /// Same as `showMixer(focusing:)` for the detached window.
    func showMixerWindow(focusing app: AudioApp? = nil) {
        reveal(app: app, present: { [weak self] in self?.presenter?.presentMixerWindow() })
    }

    private func reveal(app: AudioApp?, present: () -> Void) {
        if let app { manager?.requestFocus(app) }
        present()
        DispatchQueue.main.async { [weak self] in
            self?.manager?.replayFocus()
        }
    }
}
