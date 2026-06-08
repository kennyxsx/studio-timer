// StudioTimer/Views/DurationField.swift
import SwiftUI

/// Hours + minutes wheel picker for a duration stored as a total number of
/// minutes. Replaces the cumbersome 5-minute Stepper used in the manual-entry
/// and classify forms: any length is reachable in a flick or two, with
/// 1-minute precision (so a timer-derived draft of e.g. 47 min stays 47 rather
/// than snapping to the nearest 5).
///
/// Storage stays "total minutes" — callers keep their existing
/// `durationMinutes: Int` state and bind it here; this view just splits it into
/// hours/minutes wheels and recombines on change. Max representable is 23h59m,
/// which covers any realistic manual time entry.
struct DurationField: View {
    @Binding var totalMinutes: Int

    private var hours: Int { totalMinutes / 60 }
    private var minutes: Int { totalMinutes % 60 }

    var body: some View {
        HStack(spacing: 0) {
            Picker("Hours", selection: Binding(
                get: { hours },
                set: { totalMinutes = $0 * 60 + minutes }
            )) {
                ForEach(0..<24, id: \.self) { h in
                    Text("\(h) h").tag(h)
                }
            }
            .pickerStyle(.wheel)

            Picker("Minutes", selection: Binding(
                get: { minutes },
                set: { totalMinutes = hours * 60 + $0 }
            )) {
                ForEach(0..<60, id: \.self) { m in
                    Text("\(m) m").tag(m)
                }
            }
            .pickerStyle(.wheel)
        }
        .frame(maxHeight: 160)
    }
}
