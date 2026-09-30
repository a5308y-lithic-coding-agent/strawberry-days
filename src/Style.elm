module Style exposing (css)


css : String
css =
    """
:root {
  --bg: #fff7f4;
  --surface: #ffffff;
  --ink: #3b1d24;
  --muted: #7a5a61;
  --line: #f1dde1;
  --berry: #d62d4b;
  --berry-strong: #a81f38;
  --berry-soft: #f58ea0;
  --blush: #ffe1e7;
  --track: #fbd0d9;
  --leaf: #2f8a4f;
  --leaf-soft: #dff2e5;
  --on-berry: #ffffff;
  --shadow: 0 6px 24px rgba(168, 31, 56, 0.08);
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg: #1c1215;
    --surface: #2a1b20;
    --ink: #fbe9ec;
    --muted: #c3a2a9;
    --line: #432a31;
    --berry: #f0506b;
    --berry-strong: #ff7a90;
    --berry-soft: #9c3448;
    --blush: #43222b;
    --track: #4d2731;
    --leaf: #6fd08f;
    --leaf-soft: #1f3a29;
    --on-berry: #1c1215;
    --shadow: none;
  }
}

* { box-sizing: border-box; }

html, body {
  margin: 0;
  background: var(--bg);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
  -webkit-tap-highlight-color: transparent;
}

button, input, textarea { font: inherit; color: inherit; }
button { cursor: pointer; }
button:disabled { cursor: default; }
:focus-visible { outline: 3px solid var(--berry-soft); outline-offset: 2px; }

.app {
  max-width: 480px;
  margin: 0 auto;
  min-height: 100vh;
  padding: 0 16px calc(96px + env(safe-area-inset-bottom));
}

.header { padding: 28px 4px 12px; }
.header h1 { margin: 0; font-size: 26px; font-weight: 700; }
.header .sub { margin-top: 4px; color: var(--muted); font-size: 15px; }

.card {
  background: var(--surface);
  border-radius: 20px;
  padding: 18px;
  margin: 14px 0;
  box-shadow: var(--shadow);
  border: 1px solid var(--line);
}
.card h3 { margin: 0 0 6px; font-size: 17px; }
.card p { margin: 0; line-height: 1.5; color: var(--muted); }

/* Home ring (a meter: fill and track are steps of the same ramp) */
.ring {
  width: 240px;
  height: 240px;
  margin: 16px auto 8px;
  border-radius: 50%;
  display: grid;
  place-items: center;
}
.ring-inner {
  width: 200px;
  height: 200px;
  border-radius: 50%;
  background: var(--bg);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 16px;
}
.ring-big { font-size: 48px; font-weight: 600; line-height: 1.1; }
.ring-small { color: var(--muted); font-size: 15px; margin-top: 4px; }
.ring-caption { color: var(--muted); font-size: 13px; margin-top: 10px; }

.actions { display: flex; flex-direction: column; gap: 10px; margin: 18px 0; }

.btn {
  border: none;
  border-radius: 999px;
  padding: 14px 20px;
  font-size: 16px;
  font-weight: 600;
  width: 100%;
}
.btn.primary { background: var(--berry); color: var(--on-berry); }
.btn.primary:active { background: var(--berry-strong); }
.btn.secondary { background: var(--blush); color: var(--berry-strong); }
.btn.ghost { background: transparent; color: var(--muted); }
.btn.danger { background: transparent; color: var(--berry-strong); border: 1px solid var(--track); }

.rows { display: flex; flex-direction: column; gap: 12px; }
.row { display: flex; justify-content: space-between; align-items: baseline; gap: 12px; }
.row .label { color: var(--muted); }
.row .value { font-weight: 600; text-align: right; }

.fineprint { color: var(--muted); font-size: 12px; line-height: 1.5; text-align: center; margin: 24px 12px; }

/* Calendar */
.month-nav { display: flex; align-items: center; justify-content: space-between; margin: 8px 0 12px; }
.month-nav h2 { margin: 0; font-size: 19px; }
.icon-btn {
  width: 44px; height: 44px;
  border-radius: 50%;
  border: 1px solid var(--line);
  background: var(--surface);
  font-size: 22px;
  line-height: 1;
}

.weekdays, .grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 6px; }
.weekdays div { text-align: center; font-size: 12px; color: var(--muted); padding-bottom: 4px; }

.day {
  position: relative;
  aspect-ratio: 1;
  border-radius: 50%;
  border: 2px solid transparent;
  background: transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 15px;
  padding: 0;
}
.day.other-month { opacity: 0.35; }
.day.future { color: var(--muted); }
.day.today { font-weight: 800; border-color: var(--ink); }
.day.fertile { background: var(--leaf-soft); }
.day.ovulation { background: var(--leaf-soft); border-color: var(--leaf); }
.day.predicted { background: var(--blush); border: 2px dashed var(--berry-soft); }
.day.flow-spotting { border: 2px dotted var(--berry); }
.day.flow-light { background: var(--track); }
.day.flow-medium { background: var(--berry-soft); }
.day.flow-heavy { background: var(--berry); color: var(--on-berry); }
.day .dot {
  position: absolute;
  bottom: 4px;
  width: 5px; height: 5px;
  border-radius: 50%;
  background: currentColor;
  opacity: 0.7;
}

.legend { display: flex; flex-wrap: wrap; gap: 10px 16px; margin: 18px 4px 0; font-size: 13px; color: var(--muted); }
.legend span { display: inline-flex; align-items: center; gap: 6px; }
.swatch { width: 14px; height: 14px; border-radius: 50%; display: inline-block; border: 2px solid transparent; }
.swatch.flow { background: var(--berry); }
.swatch.predicted { background: var(--blush); border: 2px dashed var(--berry-soft); }
.swatch.fertile { background: var(--leaf-soft); }
.swatch.ovulation { background: var(--leaf-soft); border-color: var(--leaf); }

.hint { color: var(--muted); font-size: 13px; text-align: center; margin-top: 16px; }

/* Insights */
.tiles { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin: 14px 0; }
.tile {
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 16px;
  padding: 14px 10px;
  box-shadow: var(--shadow);
}
.tile .tile-label { font-size: 12px; color: var(--muted); }
.tile .tile-value { font-size: 26px; font-weight: 600; margin-top: 4px; }
.tile .tile-unit { font-size: 13px; color: var(--muted); font-weight: 400; }

table { width: 100%; border-collapse: collapse; font-size: 14px; }
th { text-align: left; color: var(--muted); font-weight: 500; font-size: 12px; padding: 0 0 8px; }
td { padding: 10px 0; border-top: 1px solid var(--line); font-variant-numeric: tabular-nums; }
th.num, td.num { text-align: right; }

/* Editor sheet */
.backdrop {
  position: fixed; inset: 0;
  background: rgba(40, 10, 18, 0.45);
  display: flex;
  align-items: flex-end;
  justify-content: center;
  z-index: 20;
}
.sheet {
  background: var(--bg);
  width: 100%;
  max-width: 480px;
  max-height: 92vh;
  overflow-y: auto;
  border-radius: 24px 24px 0 0;
  padding: 20px 18px calc(20px + env(safe-area-inset-bottom));
}
.sheet h2 { margin: 0 0 4px; font-size: 20px; }
.sheet h4 { margin: 20px 0 10px; font-size: 14px; color: var(--muted); font-weight: 600; }
.chips { display: flex; flex-wrap: wrap; gap: 8px; }
.chip {
  border: 1px solid var(--line);
  background: var(--surface);
  border-radius: 999px;
  padding: 9px 14px;
  font-size: 14px;
}
.chip.on { background: var(--berry); border-color: var(--berry); color: var(--on-berry); }
.chip.leaf.on { background: var(--leaf); border-color: var(--leaf); color: var(--on-berry); }
textarea, input[type=text], input[type=password], input[type=number] {
  width: 100%;
  border: 1px solid var(--line);
  background: var(--surface);
  border-radius: 14px;
  padding: 12px 14px;
  font-size: 16px;
}
textarea { min-height: 80px; resize: vertical; }
.sheet .actions { margin-bottom: 0; }

/* Forms */
.field { display: block; margin: 12px 0; }
.field span { display: block; font-size: 14px; color: var(--muted); margin-bottom: 6px; }
.error { color: var(--berry-strong); font-size: 14px; margin: 8px 0 0; }

/* Auth screens */
.auth {
  max-width: 380px;
  margin: 0 auto;
  min-height: 100vh;
  padding: 48px 24px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  text-align: center;
}
.auth .berry { font-size: 72px; }
.auth h1 { margin: 12px 0 8px; font-size: 28px; }
.auth p { color: var(--muted); line-height: 1.5; margin: 0 0 20px; }
.auth form { text-align: left; }
.auth .btn { margin-top: 12px; }

.splash { min-height: 100vh; display: grid; place-items: center; font-size: 64px; animation: pulse 1.2s ease-in-out infinite; }
@keyframes pulse { 50% { transform: scale(1.12); } }

/* Bottom navigation */
.nav {
  position: fixed;
  left: 0; right: 0; bottom: 0;
  background: var(--surface);
  border-top: 1px solid var(--line);
  display: flex;
  justify-content: center;
  padding-bottom: env(safe-area-inset-bottom);
  z-index: 10;
}
.nav-inner { display: flex; width: 100%; max-width: 480px; }
.nav button {
  flex: 1;
  border: none;
  background: none;
  padding: 10px 0 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  font-size: 12px;
  color: var(--muted);
}
.nav button .icon { font-size: 22px; filter: grayscale(0.8); opacity: 0.7; }
.nav button.active { color: var(--berry-strong); font-weight: 600; }
.nav button.active .icon { filter: none; opacity: 1; }

.notice {
  position: fixed;
  left: 50%;
  bottom: calc(84px + env(safe-area-inset-bottom));
  transform: translateX(-50%);
  background: var(--ink);
  color: var(--bg);
  padding: 10px 18px;
  border-radius: 999px;
  font-size: 14px;
  z-index: 30;
  max-width: calc(100% - 32px);
  text-align: center;
}
"""
