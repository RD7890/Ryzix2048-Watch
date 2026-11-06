# Ryzix 2048 Watch (Flutter, Android / Wear)

Smartwatch edition of Ryzix 2048 — package **`com.ryzix2048.watch`**.
Same game engine, hint engine, save/resume and sounds as the phone build; only
the UI/UX was redesigned for a small screen.

## Design ("Ember")

- Pure-black AMOLED base, copper / blush / cream accents sampled from the
  copper-marble watch face reference (`assets/images/planet.jpg` is the
  backdrop, painted once, dimmed per screen).
- Thin wide Poppins numerals + small Poppins labels, `FRI 11/06` date header.
- One scale unit (`context.u`, see `lib/watch.dart`): the UI is laid out on a
  200 x 235 canvas and scales to any watch screen. Fonts never go below 9 px.
- Swipe anywhere to play. The hint button glows the recommended edge of the
  board (tap again to auto-play it). Undo / Hint / Restart live in a capsule dock.
- Dialogs open inside the watch viewport. On a phone (shortest side >= 300 dp)
  the app is previewed inside a watch-shaped frame; on a real watch it is full-screen.

## Game logic

`lib/game.dart`, `lib/hint_engine.dart`, `lib/store.dart`, `lib/sound.dart`
are unchanged. In `game_screen.dart` all game-flow methods are unchanged; the
only tweak is that the swipe distance scales with the screen (`_swipeMin`).

## Permanent signing key

`signing/signing-key.jks` is committed, so every CI build is signed with the same key.

```
alias:    ryzix
store/key password: ryzix2048
```

## Build

CI (`.github/workflows/build.yml`) generates the Android scaffold with
`--org com.ryzix2048 --project-name watch`, verifies applicationId/namespace
(`.github/patch_manifest.py`), wires signing, builds the release APK, renames it
`Ryzix2048-Watch-v1.0.<run>.apk` and publishes a GitHub Release.

`push_aio.py` / `poll_actions.sh` target the repo `RD7890/Ryzix2048-Watch-Flutter`
and read the token from the `GITHUB_PAT` environment variable.

## Fonts

Poppins (Light / Regular / Medium) — SIL Open Font License 1.1. Nunito 700 is
kept only as a glyph fallback.
