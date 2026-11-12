# Matinee

An iOS 6 Letterboxd client: cloudflare is making this hard so.. relay it is *still

The phone never holds a Letterboxd password. It talks to the relay; the relay owns the cookie and talks to Letterboxd and TMDB.

<p align="center">
  <img src="docs/screenshots/diary.png" width="220" alt="Diary, with the orb mark as the only navigation title">
  <img src="docs/screenshots/film.png" width="220" alt="Film detail with a shaped iOS 6 back button">
  <img src="docs/screenshots/log-sheet.png" width="220" alt="Log sheet with green stars and send footer">
  <img src="docs/screenshots/profile.png" width="220" alt="Profile with the relay-owned session status">
</p>


Search needs a TMDB key. Without one, Search shows: “Search is powered by TMDB. Add TMDB_API_KEY to the relay to turn it on.”



## Legal

Matinee is an unofficial client. It is not affiliated with Letterboxd or TMDB. Poster images and film metadata belong to their respective owners. The relay reads public RSS and film pages; the optional write path posts a diary entry with the account owner's own session and is unsupported by Letterboxd. Respect Letterboxd's terms and do not hammer the site: the relay caches feeds for five minutes and posters for a day.
