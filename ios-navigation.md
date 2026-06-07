# iOS navigation & toolbar rules

## The one rule that matters: never nest navigation containers

**A `NavigationStack` must never wrap a `TabView` whose tabs each contain
their own `NavigationStack`.** The canonical shape is:

```swift
TabView {
    NavigationStack { ... }   // tab 1 owns its bar
    NavigationStack { ... }   // tab 2 owns its bar
}
// ← nothing (no NavigationStack) around the TabView
```

NOT:

```swift
NavigationStack {             // ← WRONG: outer container
    TabView {
        NavigationStack { ... }   // inner container per tab
        NavigationStack { ... }
    }
}
```

### Why

A `NavigationStack` is a *navigation-bar owner*. There must be **exactly one
owner per visible screen region**. A `TabView` already swaps which inner stack
is on screen, so each tab supplies its own owner. Wrapping the whole `TabView`
in another `NavigationStack` creates two claimants for the same top strip.

SwiftUI then cannot deterministically decide which bar owns the top and how to
merge the outer and inner `.toolbar` contributions. It recomputes that
resolution on every re-render (tab switch, modal re-present, any `@State`-driven
body re-evaluation — e.g. a live `Text(_, style: .timer)` tick). On some passes
the inner trailing items render; on most they are silently dropped. The result
is toolbar buttons that are **"very often simply gone"** — present sometimes,
missing other times.

### History

This bit us once: commit `e58812a` ("replace TabView root with WebView shell +
Timer modal") wrapped the previously root-level `TabView` in a new outer
`NavigationStack` purely to host a "Done" button. That introduced the nesting,
and the gear (Settings) + "+" (manual entry) buttons on the Timer modal started
disappearing intermittently. The fix removed the outer `NavigationStack` and
moved "Done" into each tab's own toolbar (each tab already had a
`NavigationStack`). See `RootView.swift`, `TimerView.swift`, `HistoryView.swift`,
`DraftsListView.swift`.

### Corroboration

- swift-composable-architecture discussion #2458 — identical structure (outer
  `NavigationStack` around a `TabView`, inner `NavigationStack` per tab);
  reported titles not showing and toolbar items colliding. Maintainer fix: drop
  the outer `NavigationStack`.
- Apple Developer Forums #667107 — with nested navigation, "SwiftUI may not know
  which toolbar should be displayed when multiple views are involved."

## Dismissing the Timer modal

The Timer modal is a `.fullScreenCover(isPresented: $router.showingTimer)`.
`AppRouter.showingTimer` is the single source of truth. To dismiss from anywhere
inside the cover, call `router.closeTimer()` (sets the binding false). Because
every tab has its own bar, each tab's toolbar carries its own leading "Done"
button that calls `router.closeTimer()`.

## Toolbar placement convention

Within this app, use `.topBarLeading` for dismissal/back-style actions and
`.topBarTrailing` for primary actions (add, settings). Avoid mixing
`.primaryAction` and `.topBarTrailing` for the same logical role across tabs —
they resolve to the same slot on iPhone but the inconsistency is a readability
trap.
