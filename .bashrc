
export PATH="/home/danick/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
alias claude='claude --dangerously-skip-permissions'
alias codex='codex --dangerously-bypass-approvals-and-sandbox'
alias config='sudo nano /etc/nixos/configuration.nix'
alias rebuild='sudo nixos-rebuild switch'
alias gi='~/.tools/gitinclude'
alias udf='~/.tools/udf'

killport() {
	if [[ $# -ne 1 || ! $1 =~ ^[0-9]+$ || $1 -lt 1 || $1 -gt 65535 ]]; then
		echo "Usage: killport <port (1-65535)>" >&2
		return 2
	fi

	local -a pids
	mapfile -t pids < <(
		{
			lsof -nP -t -iTCP:"$1" -sTCP:LISTEN 2>/dev/null
			lsof -nP -t -iUDP:"$1" 2>/dev/null
		} | sort -u
	)
	if ((${#pids[@]} == 0)); then
		echo "No process found using port $1" >&2
		return 1
	fi

	kill -TERM -- "${pids[@]}"
}

udf >/dev/null 2>&1 &
