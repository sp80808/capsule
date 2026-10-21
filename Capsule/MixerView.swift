//
//  MixerView.swift
//  Capsule
//
//  The mixer itself. One view, two homes: the menu bar popover (`compact`) and
//  the detached window. Right-clicking any row reveals the app context menu.
//

import CoreAudio
import SwiftUI

struct MixerView: View {

    @ObservedObject var manager: AudioManager

    /// Fixed 360×540 layout for the menu bar popover, flexible for the window.
    var compact: Bool = true

    @State private var query: String = ""
    @State private var isSavingSnapshot = false
    @State private var snapshotName: String = ""

    private var filteredApps: [AudioApp] {
        let visible = manager.visibleApps
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return visible }
        return visible.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)
            masterSection
                .padding(.horizontal, CapsuleTheme.gutter)
                .padding(.vertical, 12)
            Divider().opacity(0.35)
            if manager.visibleApps.count > 5 {
                searchField
                    .padding(.horizontal, CapsuleTheme.gutter)
                    .padding(.top, 10)
            }
            appList
            Divider().opacity(0.35)
            footer
        }
        .frame(width: compact ? 360 : nil, height: compact ? 540 : nil)
        .frame(
            minWidth: compact ? nil : 420,
            idealWidth: compact ? nil : 480,
            minHeight: compact ? nil : 380,
            idealHeight: compact ? nil : 620
        )
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        .alert("Save current mix", isPresented: $isSavingSnapshot) {
            TextField("Name", text: $snapshotName)

            Button("Save") {
                manager.captureSnapshot(named: snapshotName)
                snapshotName = ""
            }

            Button("Cancel", role: .cancel) {
                snapshotName = ""
            }
        } message: {
            Text("Saving again with the same name replaces it.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.title3)
                .foregroundColor(.primary)

            Text("Capsule")
                .font(.title3)
                .fontWeight(.semibold)

            if manager.demoMode {
                Text("DEMO")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange.opacity(0.25)))
                    .foregroundColor(.orange)
                    .help("Playback levels are simulated until the Capsule audio driver is installed. Turn this off in Settings.")
            }

            Spacer()

            snapshotMenu

            headerButton("arrow.clockwise", help: "Refresh app list") {
                manager.refreshApps()
                manager.refreshDevices()
            }

            if compact {
                headerButton("macwindow", help: "Open in window") {
                    MixerPresenter.shared.showMixerWindow()
                }
            }

            headerButton("gearshape", help: "Settings") {
                StatusBarController.openSettingsWindow()
            }
        }
        .padding(.horizontal, CapsuleTheme.gutter)
        .padding(.vertical, 12)
    }

    private var snapshotMenu: some View {
        Menu {
            Button("Save Current Mix…") {
                snapshotName = MixSnapshot.fallbackName()
                isSavingSnapshot = true
            }

            if !manager.snapshots.isEmpty {
                Divider()

                ForEach(manager.snapshots) { snapshot in
                    Button {
                        manager.applySnapshot(snapshot)
                    } label: {
                        Text(snapshot.name)
                    }
                }

                Divider()

                Menu("Delete Mix") {
                    ForEach(manager.snapshots) { snapshot in
                        Button(role: .destructive) {
                            manager.deleteSnapshot(snapshot)
                        } label: {
                            Text(snapshot.name)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(manager.snapshots.isEmpty ? "Saved mixes" : "\(manager.snapshots.count) saved mixes")
    }

    private func headerButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Output device / master

    @ViewBuilder
    private var masterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    manager.toggleMasterMute()
                } label: {
                    Image(systemName: manager.masterMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(manager.masterMuted ? .red : .secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(manager.masterMuted ? "Unmute output" : "Mute output")

                if manager.devices.isEmpty {
                    Text("No output device")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    Picker("", selection: deviceSelection) {
                        ForEach(manager.devices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 200)
                }

                Spacer()

                if let masterVolume = manager.masterVolume {
                    Text("\(Int((masterVolume * 100).rounded()))%")
                        .font(.system(.callout, design: .rounded))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                } else {
                    Text("Hardware")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .help("This device has no software volume control")
                }
            }

            if manager.masterVolume != nil {
                PillSlider(
                    value: Binding(
                        get: { manager.masterVolume ?? 0 },
                        set: { manager.setMasterVolume($0) }
                    ),
                    isMuted: Binding(
                        get: { manager.masterMuted },
                        set: { _ in manager.toggleMasterMute() }
                    ),
                    accessibilityName: "System output"
                )
            }
        }
    }

    private var deviceSelection: Binding<AudioDeviceID> {
        Binding(
            get: { manager.defaultDeviceID ?? 0 },
            set: { deviceID in
                guard let device = manager.devices.first(where: { $0.id == deviceID }) else { return }
                manager.selectDevice(device)
            }
        )
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            TextField("Filter apps", text: $query)
                .textFieldStyle(.plain)
                .font(.callout)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.07))
        )
    }

    // MARK: - App list

    private var appList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if filteredApps.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: CapsuleTheme.cardSpacing) {
                        ForEach(filteredApps) { app in
                            AppRowView(app: app, manager: manager)
                                .id(app.id)
                        }
                    }
                    .padding(.horizontal, CapsuleTheme.gutter)
                    .padding(.vertical, CapsuleTheme.gutter)
                }
            }
            .onAppear { scrollToFocused(proxy) }
            .onChange(of: manager.focusToken) { _ in scrollToFocused(proxy) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: query.isEmpty ? "speaker.slash" : "magnifyingglass")
                .font(.title)
                .foregroundColor(.secondary)

            Text(query.isEmpty ? "No apps to mix" : "No apps match “\(query)”")
                .font(.callout)
                .foregroundColor(.secondary)

            if !manager.hiddenAppIDs.isEmpty {
                Button("Show hidden apps") {
                    manager.revealAllHiddenApps()
                }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundColor(CapsuleTheme.accent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(.vertical, 24)
    }

    private func scrollToFocused(_ proxy: ScrollViewProxy) {
        guard let focusedAppID = manager.focusedAppID,
              filteredApps.contains(where: { $0.id == focusedAppID })
        else { return }

        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(focusedAppID, anchor: .center)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Text("\(manager.visibleApps.count) \(manager.visibleApps.count == 1 ? "app" : "apps")")
                .foregroundColor(.secondary)

            if manager.mutedCount > 0 {
                Text("·")
                    .foregroundColor(.secondary)
                Text("\(manager.mutedCount) muted")
                    .foregroundColor(.secondary)
            }

            if let soloed = manager.soloedApp {
                Text("·")
                    .foregroundColor(.secondary)
                Text("solo \(soloed.name)")
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Button("restore") {
                    manager.restoreSoloedApps()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(CapsuleTheme.accent)
                .help("Unmute the apps hidden by solo")
            }

            Spacer()

            Text("Right-click an app for more")
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, CapsuleTheme.gutter)
        .padding(.vertical, 9)
    }
}

#Preview("Menu bar mixer") {
    MixerView(manager: CapsulePreview.makeManager(), compact: true)
}
