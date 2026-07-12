# MovieSuggest Privacy Policy

_Last updated: July 2026_

MovieSuggest is designed so that your data never leaves your device.

## What we collect

**Nothing.** MovieSuggest has no accounts, no analytics, no ads, and no
tracking of any kind. We (the developer) receive no data from the app —
we run no servers.

## What stays on your device

- Your movie library (watched, favorites, watchlist) — stored in the app's
  local database.
- Your preferences (languages, genres, hidden movies, settings) — stored in
  the app's local storage.
- Your TMDB API key, if you add a personal one — stored in the iOS Keychain.

All of this is included in your device backups per your iOS settings, and is
deleted when you delete the app. The optional "Export Library" feature
creates a file only when you ask for one, containing your library and
preferences (never your API key), and shares it only where you choose to
send it.

## Network requests

The app talks to exactly one service: **The Movie Database (TMDB)**
(`api.themoviedb.org` and `image.tmdb.org`) to fetch movie information,
posters, and streaming-availability data. These requests contain the search
terms or movie IDs needed to answer them, and are subject to
[TMDB's privacy policy](https://www.themoviedb.org/privacy-policy).
MovieSuggest sends TMDB nothing about your library, identity, or device
beyond what any web request inherently includes.

If your device supports Apple Intelligence, the optional AI mood search
runs entirely **on-device** using Apple's Foundation Models framework —
your mood descriptions are never sent to any server, Apple's included.

Tapping outbound links (trailers on YouTube, "Where to Watch" pages) opens
those third-party services, which have their own privacy policies.

## Contact

Questions about this policy: open an issue on the project's repository, or
contact the developer through the App Store listing.

## Attribution

This product uses the TMDB API but is not endorsed or certified by TMDB.
