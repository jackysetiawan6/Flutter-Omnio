# Omnio

**Life, neatly together.**

Omnio is a cheerful, lightweight shared-life toolbox for planning moments and
staying connected with people.

## Current experience

- **Today**: a friendly dashboard with quick actions and upcoming events.
- **Calendar**: month navigation, optional lunar-date hints, date selection,
  event creation, and weekly recurring events.
- **People**: explicit location-sharing controls, per-person permissions, and a
  battery-saver setting that communicates lower-frequency updates.
- **Theme**: Material 3 light/dark themes with a warm purple palette, rounded
  surfaces, and small motion transitions.

## Structure

The app keeps feature state behind the `OmnioScreen` shell, while the dashboard,
calendar, and people surfaces are isolated widgets. This makes it straightforward
to move each surface into its own feature folder when persistence or backend
services are introduced.

The current event and sharing data are intentionally in-memory. A production
backend can replace these collections with repositories without changing the
navigation or presentation contracts. Location permissions, background updates,
authentication, and real-time sync should be added with platform-aware services
before release.

## Run

```bash
flutter pub get
flutter run
```
