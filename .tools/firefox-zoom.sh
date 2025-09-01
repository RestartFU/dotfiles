#!/usr/bin/env bash
# firefox-zoom-safe.sh

ZOOM=${FIREFOX_ZOOM:-1.0}

PROFILE_DIR="$HOME/.mozilla/firefox/fu17z8a7.default-release"
USERJS="$PROFILE_DIR/user.js"
TMPFILE="$(mktemp)"

# Preserve all other prefs except zoom
if [[ -f "$USERJS" ]]; then
  grep -v '^user_pref("layout.css.devPixelsPerPx"' "$USERJS" > "$TMPFILE" || true
else
  > "$TMPFILE"
fi

# Set zoom pref
echo "user_pref(\"layout.css.devPixelsPerPx\", \"$ZOOM\");" >> "$TMPFILE"
mv "$TMPFILE" "$USERJS"

# Launch Firefox safely (only if not already running)
if pgrep -x firefox >/dev/null; then
  	firefox
	exit 1
fi

exec firefox --profile "$PROFILE_DIR" "$@"

