# Letterboxd-style home screen — drop-in files

Five classes. The view layer has no dependency on `MTEntry` or `MTAppearance`;
the feed service deliberately reuses `MTSecureClient` because it is the only path
that speaks TLS 1.2 to letterboxd.com from iOS 6. MRC throughout, iOS 6 only.

| File | Role |
|---|---|
| `MTHomeTheme.h/.m` | Palette (`#14181C` bg, `#00E054` green, `#99AABB` text) + iPhone/iPad metrics |
| `MTFeedModels.h/.m` | `MTFeedItem`, `MTFeedSection`, star strings, poster URL builder, cached async image loader |
| `MTFeedService.h/.m` | Fetches `/<user>/rss/` per friend, strips headers/dechunks, parses RSS, builds rails |
| `MTPosterStripView.h/.m` | Horizontal poster rail with optional friend byline (avatar + name + stars) |
| `MTHomeViewController.h/.m` | Segmented header, three rails, friend-review list, iPad layout |

## Add to the project

Copy the ten files next to your other sources (same folder as
`MTSearchViewController.m`). If your `Makefile` uses the usual Theos wildcard:

```
Matinee_FILES = $(wildcard *.m)
```

they are picked up automatically. Otherwise add each `.m` explicitly.

`QuartzCore` is used for poster corner rounding — if it isn't already linked:

```
Matinee_FRAMEWORKS = UIKit Foundation QuartzCore
```

## Wire it into the tab bar

```objc
#import "MTHomeViewController.h"

MTHomeViewController *home = [[[MTHomeViewController alloc] init] autorelease];
home.tabBarItem = [[[UITabBarItem alloc] initWithTitle:@"Films"
                                                image:[UIImage imageNamed:@"films.png"]
                                                  tag:0] autorelease];
// replace the "Most Recent" tab (or make it the first tab)
```

`init` loads built-in demo content, so it renders immediately with real
Letterboxd posters. To drive it from live data:

```objc
home.sections = [self sectionsFromCurrentFeed];   // rebuilds automatically
[home reload];                                     // or refresh in place
```

## Real data

The screen no longer ships demo content. On appearance it calls `MTFeedService`,
which fetches `https://letterboxd.com/<username>/rss/` for every entry in
`friendUsernames` and builds the rails:

- **New from friends** — newest activity, one entry per film, with byline
- **Popular with friends** — films watched by more than one friend, most-watched first
- **Highest rated by friends** — highest `memberRating` first
- **Reviews** tab — only items that actually carry review text

```objc
MTFeedService *service = [MTFeedService sharedService];
service.friendUsernames = [NSArray arrayWithObjects:@"yourname", @"friend1", @"friend2", nil];
```

Defaults are `dave`, `matthew`, `jack` (real public accounts) so it works before you
configure anything. Replace them with the signed-in user's friends.

The service depends on one method of your transport:

```objc
[MTSecureClient sendRequestToHost:@"letterboxd.com" path:path completion:^(NSData *data, NSError *error) { … }];
```

That matches the call already used in `MTSearchViewController.m`. If the real header
differs, it is a one-line change inside `-fetchPath:completion:`.

RSS is the only un-challenged endpoint (§measured status below). It also means
`MTSecureClient` must be working for the screen to show anything — the app will show
"Tap to retry" with the transport error until it is.

### Manual items

```objc
MTFeedItem *item = [MTFeedItem itemWithTitle:entry.title
                                        year:entry.yearText
                                      poster:entry.poster];   // fragment or full URL
item.reviewerName  = @"axel";
item.avatarPath    = avatarFragment;
item.rating        = 4.5f;
item.reviewSnippet = @"…";

MTFeedSection *rail = [MTFeedSection sectionWithTitle:@"New from friends"
                                                items:items
                                          showsByline:YES];
```

Poster and avatar paths may be either full `https://` URLs or the fragment
after `/resized/` — `MTPosterURLString()` handles both. Verified working
poster form on today's site:

```
https://a.ltrbxd.com/resized/film-poster/2/6/8/2/2682-primer-0-600-0-900-crop.jpg
```

Note `-0-600-0-900-crop.jpg` is the 2:3 poster crop. The older
`-0-1000-0-1500-crop.jpg` form now returns **403**.

## What populates it — measured status

This matters before wiring: most of Letterboxd's feed is not reachable from a
non-JS client today.

| Endpoint | Status | Usable |
|---|---|---|
| `/search/<q>/` | 200 but JS shell | No results in HTML |
| `/s/search/<q>/` | 403 Cloudflare | No |
| `/films/popular/` | 200 but JS shell | No |
| `/` (home) | 403 Cloudflare | No |
| **`/<username>/rss/`** | **200, RSS with 100 real items** | **Yes — used by MTFeedService** |
| `/film/<slug>/` | 200, 205 KB | **Yes** — posters, year, cast |
| `a.ltrbxd.com/resized/...` images | 200 `image/jpeg` | **Yes** |

So the rails can be filled today from: the user's own bookmarks/watched list,
film pages the client already fetched, or a JSON movie API. "New from friends"
needs real friend data, which requires authentication the current client does
not have — the UI supports it the moment you supply `reviewerName` / `rating` /
`avatarPath`.

## iPad

Same controller, no separate code path:

- content column capped at 760 pt and centred
- posters 140×210 instead of 100×150
- all orientations allowed (`supportedInterfaceOrientations`), portrait-only on phone

## Not included (deliberate, next pass)

- Bottom tab bar restyle — that lives in your app delegate / tab controller
- Nav bar chrome above the segmented header
- Lists and Journal tabs (placeholders today)
- Film detail push on poster tap
- Any networking — this is the view layer only

## Verification status

These files were **not compiled**: this workspace has no iOS SDK, Theos or UIKit,
so no `make` run was possible. What was checked statically:

- all four pairs brace/paren/bracket balanced
- zero ARC keywords (`strong`, `weak`, `__weak`, `__strong`)
- zero iOS 7+ APIs (`tintColor`, `NSLayoutConstraint`, `UICollectionView`,
  `stringByAddingPercentEncoding…`, `NSURLSession`, `UIAlertController`)
- every `dealloc` ends with `[super dealloc];`
- every method called from a class is declared in that class's interface or
  class extension

Build it on your Mac and send me any compiler output; with `-Werror` it should
be a short list.
