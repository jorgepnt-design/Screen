import SwiftUI

struct ContentView: View {
    @ObservedObject var model: ScreenOnModel
    @State private var showsSettings = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Label(model.isActive ? "AKTIV" : "AUS", systemImage: "circle.fill")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(model.isActive ? Color.green : Color.secondary)
                        .accessibilityAddTraits(.updatesFrequently)
                    Text(model.isActive ? "Bildschirm bleibt eingeschaltet" : "Automatische Bildschirmsperre ist aktiv")
                        .font(.title3).multilineTextAlignment(.center)
                    if let start = model.startedAt {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text("Aktiv seit \(elapsed(from: start, to: context.date))")
                                .font(.title2.monospacedDigit())
                        }
                    }
                    Button(action: model.toggle) {
                        VStack(spacing: 24) {
                            Image(systemName: model.isActive ? "power" : "sun.max.fill")
                                .font(.system(size: 72, weight: .medium))
                            Text(model.isActive ? "Bildschirm wieder automatisch ausschalten" : "Bildschirm anlassen")
                                .font(.title2.bold()).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .padding(24)
                        .foregroundStyle(model.isActive ? Color.black : Color.white)
                        .background(model.isActive ? Color.green : Color.accentColor, in: RoundedRectangle(cornerRadius: 36))
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.isReady)
                    .accessibilityValue(model.isActive ? "Aktiv" : "Aus")
                    Text("Ein dauerhaft eingeschalteter Bildschirm erhöht den Akkuverbrauch.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text("Screen On endet, sobald du die App verlässt oder dein iPhone sperrst.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if let notice = model.activityNotice {
                        Text(notice).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Screen On")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showsSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Timer einstellen")
                }
            }
            .sheet(isPresented: $showsSettings) {
                NavigationStack {
                    Form {
                        Section {
                            Picker("Automatisch ausschalten", selection: $model.duration) {
                                Text("Unbegrenzt").tag(0)
                                Text("15 Minuten").tag(15)
                                Text("30 Minuten").tag(30)
                                Text("1 Stunde").tag(60)
                                Text("2 Stunden").tag(120)
                                Text("4 Stunden").tag(240)
                            }.pickerStyle(.inline)
                        } footer: {
                            Text("Die Auswahl gilt ab der nächsten Aktivierung.")
                        }
                    }
                    .navigationTitle("Timer")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { showsSettings = false } } }
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.isActive)
        }
    }

    private func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }
}
