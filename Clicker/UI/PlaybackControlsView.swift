import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject var state: AppState
    @State private var repeatCount: Int = 1
    @State private var infinite: Bool = false
    @State private var intervalValue: Double = 0
    @State private var intervalUnit: IntervalUnit = .seconds

    private enum IntervalUnit: String, CaseIterable, Identifiable {
        case seconds, minutes
        var id: String { rawValue }
        var label: String { self == .seconds ? "sec" : "min" }
        var multiplier: Double { self == .seconds ? 1 : 60 }
        var step: Double { self == .seconds ? 0.1 : 1 }
        var maxValue: Double { self == .seconds ? 3600 : 1440 }
    }

    private var intervalEnabled: Bool {
        infinite || repeatCount > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Speed")
                Picker("", selection: $state.playbackSpeed) {
                    Text("0.5×").tag(0.5)
                    Text("1×").tag(1.0)
                    Text("2×").tag(2.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            HStack {
                Text("Repeats")
                Toggle("∞", isOn: $infinite)
                if !infinite {
                    Stepper(value: $repeatCount, in: 1...9999) {
                        Text("\(repeatCount)").monospacedDigit()
                    }
                    .frame(width: 140)
                }
            }
            HStack {
                Text("Interval")
                TextField("0", value: $intervalValue, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .monospacedDigit()
                Stepper("", value: $intervalValue,
                        in: 0...intervalUnit.maxValue,
                        step: intervalUnit.step)
                    .labelsHidden()
                Picker("", selection: $intervalUnit) {
                    ForEach(IntervalUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
                .labelsHidden()
                Text("between repeats")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!intervalEnabled)
        }
        .onChange(of: repeatCount) { new in
            if !infinite { state.playbackRepeats = .count(new) }
        }
        .onChange(of: infinite) { new in
            state.playbackRepeats = new ? .infinite : .count(repeatCount)
        }
        .onChange(of: intervalValue) { new in
            updateInterval(value: new, unit: intervalUnit)
        }
        .onChange(of: intervalUnit) { newUnit in
            let clamped = min(max(0, intervalValue), newUnit.maxValue)
            if clamped != intervalValue { intervalValue = clamped }
            updateInterval(value: clamped, unit: newUnit)
        }
    }

    private func updateInterval(value: Double, unit: IntervalUnit) {
        state.playbackInterval = max(0, value) * unit.multiplier
    }
}
