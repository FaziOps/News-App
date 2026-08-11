# Daily Glass — Flutter News App

A NewsAPI.org-backed news reader with a glass morphism UI, built to the
attached PRD (2/3–1/3 home split, source picker, 7-category tab screen).


## Setup

```
flutter pub get
flutter run
```


Requires Flutter 3.x+ (Dart 3+). Not verified against a live `flutter run`
in this environment — no Flutter SDK or network access to pub.dev was
available where this was built. Run `flutter pub get` first and fix any
version resolution issues before assuming it runs clean.

## Structure

```
lib/
  main.dart                    App entry, theme, root provider
  models/article.dart          Null-safe Article model
  services/news_api_service.dart   All NewsAPI HTTP calls
  providers/home_provider.dart     Home screen state (source + both lists)
  providers/category_provider.dart Category screen state (per-tab, lazy)
  screens/home_screen.dart     2/3–1/3 split layout
  screens/category_screen.dart 7-tab category browser
  widgets/glass_container.dart Core glass morphism panel + background
  widgets/article_card.dart    Article row (image, title, tap-to-open)
  widgets/source_picker.dart   Vertical-dots source menu
  widgets/state_views.dart     Loading / error / empty states
  utils/constants.dart         API key, source IDs, category list
```

## Design decisions worth knowing about


- **Category tabs load lazily.** Opening the Category screen doesn't fire
  7 requests at once — each tab fetches on first view and caches the
  result. On a 100-requests/day free key, firing all 7 up front would burn
  7% of your daily quota on a single screen open.
- **Both home-screen lists load and fail independently.** A slow or
  broken "Other News" fetch never blocks or crashes the main headlines,
  and vice versa.
- **Source picker placement**: the PRD explicitly puts the vertical-dots
  menu on the top left, next to the category icon, deviating from the
  Material Design convention of top-right. Implemented as specified — flag
  this with your supervisor if it wasn't a deliberate call.


## Known limitations — read before calling this "production-ready"


1. **The API key is hardcoded in `lib/utils/constants.dart`.** It ships
   inside the compiled app and is trivially extractable from the APK/IPA.
   Fine for a dev build; not fine for public release. Fix: proxy all
   NewsAPI calls through your own backend and never embed the key
   client-side.
2. **NewsAPI.org's free Developer plan prohibits commercial/production
   use in its Terms of Service** and caps requests at 100/day. This app
   will function on real devices (the plan's CORS-localhost restriction
   is a browser-only mechanism and doesn't apply to Dart's native `http`
   client), but you are not compliant with NewsAPI's terms if you publish
   this. Business plan starts at $449/month if you need to go live
   legitimately.
3. **Not compiled/tested end-to-end.** Every file was written and
   manually reviewed for type correctness, null-safety, and import
   correctness, but no `flutter analyze` or `flutter run` was executed
   against it. Run `flutter analyze` first thing after `pub get`.
