# Lockd

Lockd is Strava for studying. Start a session, an on-device AI checks through your camera that you're present and facing your work, and you earn 1 point per 10 verified minutes. Weekly and all-time leaderboards.

## Run it (demo mode, no accounts)
Camera access needs a secure context, so serve over localhost:

    cd study-strava
    python3 -m http.server 8000
    # open http://localhost:8000

Demo mode keeps everything in your browser with a few fake rivals on the board.

## Go global (free)
1. Create a free project at supabase.com.
2. SQL Editor > paste `schema.sql` > Run.
3. Authentication > Providers: keep Email on (turn off "Confirm email" while testing).
4. Put your Project URL and anon key in `config.js`.
5. Host the folder free on Cloudflare Pages, Netlify or GitHub Pages (all HTTPS, so the camera works).

## How it works
- **AI referee**: MediaPipe Face Detector runs in the browser (WebAssembly/GPU). No video or photos are uploaded, so there are no API or storage costs and privacy is simple.
- **Verified** = exactly one face, facing the screen (looking down at a desk is fine). Leave frame for 10s and the clock stops until you're back.
- **Breaks**: press Take a break; points pause; breaks over 15 minutes end the session.
- **Anti-cheat on the server**: the browser sends only totals, and `submit_session()` rejects impossible ones (verified time longer than the wall clock, overlapping sessions, future dates, over 8h).

## Honest limits
A browser can't be fully trusted: someone could point the camera at a photo or a looping video, or tamper with the page and send fake totals up to the wall-clock limit. Ideas for later: liveness check (random blink/head-turn prompts), report button + friend-verified leaderboards, rate caps per day, and a custom-trained classifier (your Colab/MobileNet idea) for "is there a book/laptop in view".
