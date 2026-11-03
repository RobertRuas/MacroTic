#!/bin/bash
# Hot reload for MacroTic — watches Sources/ and rebuilds+relaunches on change

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

APP_NAME="MacroTic"
PID=""
WATCH_PID=""

cleanup() {
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null
        wait "$PID" 2>/dev/null
    fi
    if [ -n "$WATCH_PID" ] && kill -0 "$WATCH_PID" 2>/dev/null; then
        kill "$WATCH_PID" 2>/dev/null
        wait "$WATCH_PID" 2>/dev/null
    fi
    exit 0
}
trap cleanup INT TERM

kill_stale_instances() {
    local pids
    pids=$(pgrep -f "$PROJECT_DIR/.build/debug/$APP_NAME" || true)
    if [ -n "$pids" ]; then
        echo "⟳ Closing existing $APP_NAME instance(s)..."
        kill $pids 2>/dev/null
        sleep 0.3
    fi
}

build_and_run() {
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        echo "⟳ Stopping..."
        kill "$PID" 2>/dev/null
        wait "$PID" 2>/dev/null
    fi

    echo "⟳ Building..."
    if swift build 2>&1; then
        echo "✓ Running $APP_NAME"
        .build/debug/$APP_NAME &
        PID=$!
    else
        echo "✗ Build failed"
        PID=""
    fi
}

run_only() {
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        echo "⟳ Stopping..."
        kill "$PID" 2>/dev/null
        wait "$PID" 2>/dev/null
    fi

    echo "✓ Running $APP_NAME"
    .build/debug/$APP_NAME &
    PID=$!
}

restart_app() {
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        echo "⟳ Stopping..."
        kill "$PID" 2>/dev/null
        wait "$PID" 2>/dev/null
    fi

    echo "⟳ Building..."
    if swift build 2>&1; then
        echo "✓ Running $APP_NAME"
        .build/debug/$APP_NAME &
        PID=$!
    else
        echo "✗ Build failed"
        PID=""
    fi
}

show_menu() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  MacroTic Dev Menu"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  [B] Build and run"
    echo "  [R] Restart app"
    echo "  [O] Just run (no build)"
    echo "  [Q] Quit"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

menu_loop() {
    while true; do
        show_menu
        echo -n "Choose option: "
        read -rsn1 choice
        echo "$choice"
        echo ""

        case "$choice" in
            B|b)
                build_and_run
                ;;
            R|r)
                restart_app
                ;;
            O|o)
                run_only
                ;;
            Q|q)
                echo "⟳ Quitting..."
                cleanup
                ;;
            *)
                echo "✗ Invalid option. Try again."
                ;;
        esac
    done
}

monitor_app() {
    while true; do
        if [ -n "$PID" ] && ! kill -0 "$PID" 2>/dev/null; then
            echo ""
            echo "✗ App closed unexpectedly"
            PID=""
            cleanup
        fi
        sleep 1
    done
}

watch_files() {
    fswatch -o -r --event Created --event Updated --event Removed Sources/ | while read -r _; do
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            echo ""
            echo "--- Change detected ---"
            if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
                kill "$PID" 2>/dev/null
                wait "$PID" 2>/dev/null
            fi

            echo "⟳ Building..."
            if swift build 2>&1; then
                echo "✓ Running $APP_NAME"
                .build/debug/$APP_NAME &
                PID=$!
            else
                echo "✗ Build failed"
                PID=""
            fi
        fi
    done
}

echo "=== MacroTic Dev Server ==="
echo ""

kill_stale_instances

monitor_app &
MONITOR_PID=$!

watch_files &
WATCH_PID=$!

menu_loop
