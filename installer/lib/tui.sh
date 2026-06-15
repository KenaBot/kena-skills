#!/usr/bin/env bash
# tui.sh — TUI abstraction layer for kena-skills
# Tries (in order): gum > dialog > whiptail > read (fallback)
#
# Exports:
#   TUI_BACKEND              "gum" | "dialog" | "whiptail" | "read"
#   detect_tui               function: pick the best backend available
#   tui_menu <title> <items...>  -> echoes index (0-based) of selected item
#   tui_checklist <title> <items...>  -> echoes space-separated indices of selected items
#   tui_confirm <prompt>     -> echoes "y" or "n"
#   tui_input <prompt> [default]  -> echoes user input
#   tui_info <message>       -> displays info message, waits for enter

TUI_BACKEND=""

detect_tui() {
  if command -v gum >/dev/null 2>&1; then
    TUI_BACKEND="gum"
  elif command -v dialog >/dev/null 2>&1; then
    TUI_BACKEND="dialog"
  elif command -v whiptail >/dev/null 2>&1; then
    TUI_BACKEND="whiptail"
  else
    TUI_BACKEND="read"
  fi
}

tui_info() {
  local msg="$*"
  case "$TUI_BACKEND" in
    gum)
      gum style --border normal --padding "0 1" --margin "0 1" "$msg"
      ;;
    dialog)
      dialog --msgbox "$msg" 10 60
      ;;
    whiptail)
      whiptail --msgbox "$msg" 10 60
      ;;
    read)
      echo ""
      echo "  ┌─ INFO ─────────────────────"
      echo "  │ $msg"
      echo "  └────────────────────────────"
      echo "  Press Enter to continue..."
      read -r _
      ;;
  esac
}

tui_confirm() {
  local prompt="$1"
  case "$TUI_BACKEND" in
    gum)
      if gum confirm "$prompt"; then echo "y"; else echo "n"; fi
      ;;
    dialog)
      if dialog --yesno "$prompt" 10 60; then echo "y"; else echo "n"; fi
      ;;
    whiptail)
      if whiptail --yesno "$prompt" 10 60; then echo "y"; else echo "n"; fi
      ;;
    read)
      # Loop until valid y/n
      local ans
      while true; do
        echo ""
        echo "  $prompt [y/n]: "
        read -r ans
        # POSIX-portable lowercase
        local ans_lc
        ans_lc=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
        case "$ans_lc" in
          y|yes) echo "y"; return 0;;
          n|no) echo "n"; return 0;;
          *) echo "  Please answer y or n";;
        esac
      done
      ;;
  esac
}

tui_input() {
  local prompt="$1"
  local default="${2:-}"
  case "$TUI_BACKEND" in
    gum)
      if [ -n "$default" ]; then
        gum input --placeholder "$default" --prompt "$prompt: "
      else
        gum input --prompt "$prompt: "
      fi
      ;;
    *)
      if [ -n "$default" ]; then
        read -r -p "  $prompt [$default]: " ans
        echo "${ans:-$default}"
      else
        read -r -p "  $prompt: " ans
        echo "$ans"
      fi
      ;;
  esac
}

tui_menu() {
  local title="$1"
  shift
  local items=("$@")
  case "$TUI_BACKEND" in
    gum)
      local selected
      selected=$(printf "%s\n" "${items[@]}" | gum choose --header "$title" --height 10)
      # Find index
      for i in "${!items[@]}"; do
        if [ "${items[$i]}" = "$selected" ]; then
          echo "$i"
          return 0
        fi
      done
      echo "-1"
      ;;
    dialog)
      # Build args
      local args=("$title" "20" "60" "10")
      for item in "${items[@]}"; do
        args+=("$item")
      done
      local result
      result=$(dialog --menu "${args[@]}" 3>&1 1>&2 2>&3) || { echo "-1"; return 0; }
      # result is the tag (item text); find index
      for i in "${!items[@]}"; do
        if [ "${items[$i]}" = "$result" ]; then
          echo "$i"
          return 0
        fi
      done
      echo "-1"
      ;;
    whiptail)
      local args=("$title" "20" "60" "10")
      for item in "${items[@]}"; do
        args+=("$item")
      done
      local result
      result=$(whiptail --menu "${args[@]}" 3>&1 1>&2 2>&3) || { echo "-1"; return 0; }
      for i in "${!items[@]}"; do
        if [ "${items[$i]}" = "$result" ]; then
          echo "$i"
          return 0
        fi
      done
      echo "-1"
      ;;
    read)
      echo ""
      echo "  ── $title ──"
      local i=1
      for item in "${items[@]}"; do
        echo "    $i) $item"
        i=$((i+1))
      done
      echo ""
      local choice
      while true; do
        read -r -p "  Select [1-${#items[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#items[@]}" ]; then
          echo "$((choice-1))"
          return 0
        fi
        echo "  Invalid selection"
      done
      ;;
  esac
}

tui_checklist() {
  local title="$1"
  shift
  local items=("$@")
  case "$TUI_BACKEND" in
    gum)
      # gum choose --no-limit allows multi-select
      local selected_str
      selected_str=$(printf "%s\n" "${items[@]}" | gum choose --no-limit --header "$title" --height 15)
      # Convert selected items to space-separated indices
      local result=""
      while IFS= read -r sel; do
        for i in "${!items[@]}"; do
          if [ "${items[$i]}" = "$sel" ]; then
            if [ -z "$result" ]; then result="$i"; else result="$result $i"; fi
            break
          fi
        done
      done <<< "$selected_str"
      echo "$result"
      ;;
    dialog)
      local args=("$title" "20" "60" "10")
      for item in "${items[@]}"; do
        args+=("$item" "")
      done
      local result
      result=$(dialog --checklist "${args[@]}" 3>&1 1>&2 2>&3) || { echo ""; return 0; }
      # result is space-separated tags
      echo "$result"
      ;;
    whiptail)
      local args=("$title" "20" "60" "10")
      for item in "${items[@]}"; do
        args+=("$item" "")
      done
      local result
      result=$(whiptail --checklist "${args[@]}" 3>&1 1>&2 2>&3) || { echo ""; return 0; }
      echo "$result"
      ;;
    read)
      # Manual multi-select with checkboxes
      local selected=()
      for i in "${!items[@]}"; do selected[$i]=0; done
      while true; do
        echo ""
        echo "  ── $title (toggle with number, Enter to confirm) ──"
        local i=1
        for item in "${items[@]}"; do
          local mark="[ ]"
          [ "${selected[$((i-1))]}" = "1" ] && mark="[x]"
          echo "    $i) $mark $item"
          i=$((i+1))
        done
        echo ""
        read -r -p "  Toggle (1-${#items[@]}) or Enter to confirm: " choice
        if [ -z "$choice" ]; then
          # Confirm and return
          local result=""
          for i in "${!selected[@]}"; do
            if [ "${selected[$i]}" = "1" ]; then
              if [ -z "$result" ]; then result="$i"; else result="$result $i"; fi
            fi
          done
          echo "$result"
          return 0
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#items[@]}" ]; then
          local idx=$((choice-1))
          if [ "${selected[$idx]}" = "1" ]; then
            selected[$idx]=0
          else
            selected[$idx]=1
          fi
        fi
      done
      ;;
  esac
}

# Interactive main menu (used by kena-skills when no args)
interactive_main() {
  local skills_dir="$1"
  local repo_name="$2"
  local deps_auto="$3"
  local dry_run="$4"

  if [ "$TUI_BACKEND" = "read" ]; then
    echo ""
    echo "  ┌────────────────────────────────────────────────┐"
    echo "  │  kena-skills — interactive installer            │"
    echo "  └────────────────────────────────────────────────┘"
    echo ""
  fi

  # Step 1: detect agents. Avoid 'mapfile' (bash 4+) so this works
  # on macOS's default bash 3.2.
  info "Step 1/3: Detecting installed agents..."
  local -a DETECTED=()
  local _line
  while IFS= read -r _line; do
    DETECTED+=("$_line")
  done < <(detect_installed_agents)
  local -a ALL_SUPPORTED=()
  while IFS= read -r _line; do
    ALL_SUPPORTED+=("$_line")
  done < <(list_supported_agents)

  if [ ${#ALL_SUPPORTED[@]} -eq 0 ]; then
    err "No supported agents in registry. Check installer/lib/agents.json"
    exit 1
  fi

  # Build checklist items: "[installed] opencode", "[available] codex", etc.
  local checklist_items=()
  for agent in "${ALL_SUPPORTED[@]}"; do
    if printf "%s\n" "${DETECTED[@]}" | grep -qx "$agent"; then
      checklist_items+=("[installed] $agent")
    else
      checklist_items+=("[available] $agent")
    fi
  done

  echo ""
  info "Step 2/3: Select target agents (space/enter to toggle):"
  local selected_indices
  selected_indices=$(tui_checklist "Select target agents" "${checklist_items[@]}")

  if [ -z "$selected_indices" ]; then
    warn "No targets selected. Exiting."
    exit 0
  fi

  # Convert indices to agent names (strip "[installed] " or "[available] " prefix)
  local selected_targets=()
  for idx in $selected_indices; do
    local item="${checklist_items[$idx]}"
    local agent="${item#*] }"  # strip "[anything] " prefix
    selected_targets+=("$agent")
  done

  # Step 3: list skills. Avoid 'mapfile' (bash 4+) so this works
  # on macOS's default bash 3.2.
  echo ""
  info "Step 3/3: Select a skill to install:"
  local -a SKILLS=()
  local _skill_line
  while IFS= read -r _skill_line; do
    SKILLS+=("$_skill_line")
  done < <(list_skill_names "$skills_dir")
  if [ ${#SKILLS[@]} -eq 0 ]; then
    err "No skills found in $skills_dir"
    exit 1
  fi

  local skill_idx
  skill_idx=$(tui_menu "Available skills" "${SKILLS[@]}")
  if [ "$skill_idx" = "-1" ] || [ -z "$skill_idx" ]; then
    warn "No skill selected. Exiting."
    exit 0
  fi

  local chosen_skill="${SKILLS[$skill_idx]}"
  local targets_csv
  targets_csv=$(IFS=,; echo "${selected_targets[*]}")

  echo ""
  info "Installing '$chosen_skill' to: $targets_csv"
  install_skill_to_targets "$chosen_skill" "$targets_csv" "$skills_dir" "$repo_name" "$deps_auto" "$dry_run"
}
