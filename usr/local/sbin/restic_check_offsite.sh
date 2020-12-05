#!/usr/bin/env bash
# Check my backup with  restic to SFTP for errors.
# This script is typically run by: /etc/systemd/system/restic-check@offsite.{service,timer}

# Exit on failure, pipe failure
set -e -o pipefail

# Clean up lock if we are killed.
# If killed by systemd, like $(systemctl stop restic), then it kills the whole cgroup and all it's subprocesses.
# However if we kill this script ourselves, we need this trap that kills all subprocesses manually.
exit_hook() {
	echo "In exit_hook(), being killed" >&2
	jobs -p | xargs kill
	restic unlock
}
trap exit_hook INT TERM


source /etc/restic/b2_offsite_env.sh
curl -fsS -m 10 --retry 5 "https://hc-ping.com/${HC_ID}/start"

# Remove locks from other stale processes to keep the automated backup running.
# NOTE nope, don't unlock like restic_backup.sh. restic_backup.sh should take precedence over this script.
#restic unlock &
#wait $!

# Check repository for errors.
restic check \
	--verbose &
wait $!
