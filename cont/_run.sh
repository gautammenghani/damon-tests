#!/bin/bash

set -e

if [ $# -eq 1 ] && [ "$1" = "--uncond_single_run" ]
then
	uncond_single_run="--uncond_single_run"
else
	uncond_single_run=""
fi

bindir=$(dirname "$0")

lazybox_dir="$bindir/lazybox"

lazybox_gh_repo="https://github.com/sjp38/lazybox"

if [ ! -d "$lazybox_dir" ]
then
	mkdir -p "$lazybox_dir"
	git -C "$lazybox_dir" init
	git -C "$lazybox_dir" remote add origin "$lazybox_gh_repo"
fi
if ! git -C "$lazybox_dir" pull origin master
then
	echo "lazybox pull failed"
	exit 1
fi

"$lazybox_dir/humble_ci/hci.py" --repo ./linux \
	--tree_to_track al https://github.com/amazonlinux/linux \
		amazon-5.4.y/master \
	--tree_to_track al https://github.com/amazonlinux/linux \
		amazon-5.10.y/master \
	--tree_to_track stable \
		git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
		linux-5.15.y \
	--tree_to_track stable \
		git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
		linux-5.18.y \
	--tree_to_track linus \
		git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git \
		master \
	--tree_to_track akpm-mm \
		https://github.com/hnaz/linux-mm master \
	--tree_to_track akpm.korg.mm \
		git://git.kernel.org/pub/scm/linux/kernel/git/akpm/mm mm-stable \
	--tree_to_track akpm.korg.mm \
		git://git.kernel.org/pub/scm/linux/kernel/git/akpm/mm mm-unstable \
	--cmds "$bindir/_for_tree_updates.sh" \
	--delay 3600 $uncond_single_run
