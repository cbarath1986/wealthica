# MovieSuggest

A native iPhone app that suggests movies based on what you've watched, what you've favorited, and the languages you prefer. Built with SwiftUI and SwiftData, backed by [The Movie Database (TMDB)](https://www.themoviedb.org/) for the movie catalog, posters, and metadata.

## Features

- **For You** — a personalized feed, re-ranked from your watch history and favorites, boosted toward your preferred languages.
- **Discover** — search TMDB's catalog or browse what's trending.
- **My Movies** — everything you've marked watched or favorited, in one place.
- **Settings** — manage your TMDB API key and preferred languages, including an option to only show movies in those languages.

Everything about your taste — watch history, favorites, language settings — stays on your device. The only network calls are to TMDB.

## Requirements

- macOS with **Xcode 16 or later**
- An iOS 17+ simulator or device
- A free TMDB API key (see below)

## Getting a TMDB API key

1. Create a free account at [themoviedb.org](https://www.themoviedb.org/signup).
2. Go to **Settings → API** and request a key (choose "Developer" — it's free and instant for personal use).
3. Copy the **API Key (v3 auth)** value — you'll paste it into the app on first launch.

## Build & run

1. Clone the repo and check out this branch:
   ```
   git checkout claude/movie-suggestion-iphone-app-27fmyw
   ```
2. Open the project:
   ```
   open MovieSuggest/MovieSuggest.xcodeproj
   ```
3. Pick an iPhone simulator (e.g. "iPhone 16") from the scheme selector.
4. Press **Cmd+R** to build and run. On first launch, paste your TMDB API key and pick your preferred languages.

### Fallback: if the project won't open

This project uses Xcode 16's file-system-synchronized groups. If you're on an older Xcode and the `.xcodeproj` won't open, recreate it manually:

1. **File → New → Project → iOS → App**, name it `MovieSuggest`, interface **SwiftUI**, storage **SwiftData**.
2. Delete the template's generated `ContentView.swift` and `Item.swift`.
3. Drag the `MovieSuggest/MovieSuggest` folder from this repo into the project navigator (uncheck "Copy items if needed" is fine either way; make sure "Add to target: MovieSuggest" is checked).
4. Add a test target: **File → New → Target → Unit Testing Bundle**, name it `MovieSuggestTests`.
5. Drag the `MovieSuggest/MovieSuggestTests` folder in, adding it to the `MovieSuggestTests` target.
6. Set the deployment target to iOS 17.0 for both targets, then build.

## How recommendations work

MovieSuggest scores candidate movies against your history entirely on-device:

1. **Taste profile** — every genre from your watched and favorited movies contributes to a genre-affinity score. Favorites count 3x as much as plain watches, and older interactions fade gradually (recent taste matters more, but old favorites are never fully forgotten).
2. **Candidates** come from two sources: TMDB's "recommended"/"similar" lists for your five most recent favorites, and a "discover" query filtered to your top genres and preferred languages.
3. **Scoring** blends genre match (45%), how often a candidate showed up as similar to your favorites (25%), whether it's in a preferred language (20%), and its TMDB rating (10%). Movies you've already watched are always excluded.
4. Language is a *boost* by default — a great match in another language can still surface. Turn on **Only Preferred Languages** in Settings to filter strictly instead.

With an empty history, For You shows what's trending, boosted toward your preferred languages, with a prompt to start marking movies.

## Architecture

```
MovieSuggest/
├── Models/Movie.swift          SwiftData model — the only persisted data
├── Networking/                 TMDBClient (async/await), DTOs, image URLs
├── Recommendation/             Pure, dependency-free scoring engine
├── Services/                   Keychain (API key), UserDefaults (settings, genre cache)
├── Support/Language.swift      Curated language list
└── Views/                      For You, Discover, My Movies, Detail, Settings, Onboarding
```

SwiftData stores only movies you've interacted with; search results and recommendations are fetched live and kept in memory.

## Running the tests

- In Xcode: **Cmd+U**.
- From the command line:
  ```
  xcodebuild test -project MovieSuggest/MovieSuggest.xcodeproj -scheme MovieSuggest \
    -destination 'platform=iOS Simulator,name=iPhone 16'
  ```

`RecommendationEngineTests` covers the scoring logic (genre affinity, exclusion of watched movies, language boosting/filtering, recency decay, deterministic ordering). `TMDBModelDecodingTests` covers decoding real TMDB response shapes, including nulls and empty fields.

## Privacy

Your watch history, favorites, and settings never leave your device — they're stored in SwiftData and UserDefaults locally. Your TMDB API key is stored in the iOS Keychain. The only network traffic is direct calls from your device to TMDB's API.

This product uses the TMDB API but is not endorsed or certified by TMDB.

## App Store launch checklist

The code is App Store-ready; the remaining steps are account/config work
that must happen on your side:

1. **Join the Apple Developer Program** ($99/year) at
   [developer.apple.com](https://developer.apple.com/programs/), and sign in
   to Xcode with that account (Xcode → Settings → Accounts).
2. **Set your bundle identifier.** In the project's Signing & Capabilities
   tab, change `com.example.MovieSuggest` to your own reverse-domain id
   (e.g. `com.yourname.moviesuggest`) and select your team. Do the same for
   the test target.
3. **Embed a TMDB key** so users don't have to bring their own: paste your
   key into `MovieSuggest/Services/DefaultAPIKey.swift`. Onboarding then
   skips the key screen entirely; users can still add a personal key in
   Settings. Leave it empty to keep the bring-your-own-key flow.
   (TMDB's free API is for non-commercial use — keep the app free, keep the
   attribution, and don't add ads or purchases without a TMDB commercial
   agreement.)
4. **Host the privacy policy** — `PRIVACY.md` in this repo is written to
   match exactly what the app does. Put it anywhere public (GitHub Pages
   works) and use that URL in App Store Connect.
5. **App Privacy questionnaire** in App Store Connect: answer
   **"Data Not Collected"** — the app has no analytics, accounts, or
   tracking, and the included `PrivacyInfo.xcprivacy` manifest already
   declares the same.
6. **TestFlight first**: Product → Archive → Distribute App → TestFlight.
   Use it yourself for a week; then submit the same build for App Store
   review with screenshots (6.7" and 6.1" sizes cover current requirements)
   and a short description.
7. In the reviewer notes, mention: no account is needed, all data is
   on-device, and the AI mood search only appears on Apple
   Intelligence-capable devices (reviewers on older hardware will simply
   not see it — that's by design, not a broken feature).

## Troubleshooting

- **"TMDB rejected the API key"** — double-check you copied the v3 API key (not the "Read Access Token"), and re-enter it in Settings.
- **"TMDB rate limit reached"** — wait a few seconds and pull to refresh.
- **For You is empty / shows only trending** — you haven't marked any movies as watched or favorite yet. Search in Discover and mark a few from their detail screens.
