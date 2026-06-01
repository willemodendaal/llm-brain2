#!/usr/bin/env bash
# Launches a Claude Code instance using the personal config/login
# (isolated from the default ~/.claude instance).
export CLAUDE_CONFIG_DIR="$HOME/.claude-personal"
exec claude "$@"
