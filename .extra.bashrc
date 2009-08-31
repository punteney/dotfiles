######
# .extra.bashrc - Isaac's Bash Extras
# This file is designed to be a drop-in for any machine that I log into.
# Currently, that means it has to work under Darwin, Ubuntu, and yRHEL
# 
# Per-platform includes at the bottom, but most functionality is included
# in this file, and forked based on resource availability.
# 
# Functions are preferred over shell scripts, because then there's just
# a few files to rsync over to a new host for me to use it comfortably.
# 
# .extra_Darwin.bashrc has significantly more stuff, since my mac is also
# a GUI environment, and my primary platform.
######


# Note for Leopard Users #
# If you use this, it will probably make your $PATH variable pretty long,
# which will cause terrible performance in a stock Leopard install.
# To fix this, comment out the following lines in your /etc/profile file:

# if [ -x /usr/libexec/path_helper ]; then
# 	eval `/usr/libexec/path_helper -s`
# fi

# Thanks to "allan" in irc://irc.freenode.net/#textmate for knowing this!


echo "loading bash extras..."

# i like my aliases.  please always have them!
shopt expand_aliases &>/dev/null

if [ "$BASH_COMPLETION_DIR" == "" ]; then
	[ -f /opt/local/etc/bash_completion ] && . /opt/local/etc/bash_completion
	[ -f /etc/bash_completion ] && . /etc/bash_completion
fi

# set some globals
if ! [ -f "$HOME" ]; then
	export HOME="$(echo ~)"
fi

path=$HOME/bin:$HOME/scripts:/opt/local/sbin:/opt/local/bin:/opt/local/libexec:/usr/local/sbin:/usr/local/bin:/usr/local/libexec:/usr/sbin:/usr/bin:/usr/libexec:/sbin:/bin:/libexec:/usr/X11R6/bin:/opt/local/include:/usr/local/include:/usr/include:/usr/X11R6/include
! [ -d ~/bin ] && mkdir ~/bin
path_elements="${path//:/ }"
path=""
for i in $path_elements; do
	[ -d $i ] && path="$path$i "
done
export PATH=$(path=$(echo $path); echo ${path// /:})
unset path


# Use UTF-8, and throw errors in PHP and Perl if it's not available.
# Note: this is VERY obnoxious if UTF8 is not available!
# That's the point!
export LC_CTYPE=en_US.UTF-8
export LC_ALL=""
export LANG=$LC_CTYPE
export LANGUAGE=$LANG
export TZ=America/New_York
export HISTSIZE=1000000
export HISTFILESIZE=1000000000

# append to history rather than overwriting.
shopt -s histappend

# don't be so prickly about spelling
shopt -s cdspell

export CDPATH=.:..:$HOME/projects:$HOME

alias ..="cd .."

# read a line from stdin, write to stdout.
getln () { read "$@" t && echo $t; }

# chooses the first argument that matches a file in the path.
choose_first () {
	for i in "$@"; do
		if ! [ -f "$i" ] && inpath "$i"; then
			i="$(which "$i")"
		fi
		if [ -f "$i" ]; then
			echo $i
			break
		fi
	done
}

# fail if the file is not an executable in the path.
inpath () {
	! [ $# -eq 1 ] && echo "usage: inpath <file>" && return 1
	f="$(which "$1" 2>/dev/null)"
	[ -f "$f" ] && return 0
	return 1
}

# show a certain line of a file, or stdin
line () {
	sed ${1-0}'!d;q' < ${2-/dev/stdin}
}

# headless <command> [<key>]
# to reconnect, do: headless "" <key>
headless () {
	if [ "$2" == "" ]; then
		hash=$(md5 -qs "$1")
	else
		hash="$2"
	fi
	if [ "$1" != "" ]; then
		dtach -n /tmp/headless-$hash bash -l -c "$1"
	else
		dtach -A /tmp/headless-$hash bash -l
	fi
}

# do something in the background
back () {
	( "$@" ) &
}
# do something very quietly.
quiet () {
	( "$@" ) &>/dev/null
}
#do something to all the things on standard input.
# echo 1 2 3 | foreach echo foo is like calling echo foo 1; echo foo 2; echo foo 3;
foreach () {
	for i in $(cat /dev/stdin); do
		"$@" $i;
	done
}

# test javascript files for syntax errors.
#if inpath yuicompressor; then
#	testjs () {
#		for i in $(find . -name "*.js"); do
#			err="$(yuicompressor -o /dev/null $i 2>/dev/stdout)"
#			if [ "$err" != "" ]; then
#				echo "$i has errors:"
#				echo "$err"
#			fi
#		done
#	}
#fi

# give a little colou?r to grep commands, if supported
grep=grep
if [ "$(grep --help | grep color)" != "" ]; then
	grep="grep --color"
elif [ "$(grep --help | grep colour)" != "" ]; then
	grep="grep --colour"
fi
alias grep="$grep"


# substitute "this" for "that" if "this" exists and is in the path.
substitute () {
	! [ $# -eq 2 ] && echo "usage: substitute <desired> <orig>" && return 1
	inpath "$1" && new="$(which "$1")" && alias $2="$new"
}

substitute yssh ssh
substitute yscp scp


#[ -d ~/dev/main/yahoo ] && export SRCTOP=~/dev/main/yahoo 

#has_yinst=0
#inpath yinst && has_yinst=1

# useful commands:
_set_editor () {
	edit_cmd="$( choose_first "$@" )"
	if [ -f "$edit_cmd" ]; then
		if [ -f "${edit_cmd}_wait" ]; then
			export EDITOR="${edit_cmd}_wait"
		else
			export EDITOR="$edit_cmd"
		fi
	fi
	alias edit="$edit_cmd"
	alias sued="sudo $edit_cmd"
}
# my list of editors, by preference.
_set_editor mate nano pico vim vi ed
unset _set_editor
#alias js="rlwrap narwhal"

# shebang <file> <program> [<args>]
shebang () {
	sb="shebang"
	if [ $# -lt 2 ]; then
		echo "usage: $sb <file> <program> [<arg string>]"
		return 1
	elif ! [ -f "$1" ]; then
		echo "$sb: $1 is not a file."
		return 1
	fi
	if ! [ -w "$1" ]; then
		echo "$sb: $1 is not writable."
		return 1
	fi
	prog="$2"
	! [ -f "$prog" ] && prog="$(which "$prog" 2>/dev/null)"
	if ! [ -x "$prog" ]; then
		echo "$sb: $2 is not executable, or not in path."
		return 1
	fi
	chmod ogu+x "$1"
	prog="#!$prog"
	[ "$3" != "" ] && prog="$prog $3"
	if ! [ "$(head -n 1 "$1")" == "$prog" ]; then
		tmp=$(mktemp shebang.XXXX)
		( echo $prog; cat $1 ) > $tmp && cat $tmp > $1 && rm $tmp && return 0 || \
			echo "Something fishy happened!" && return 1
	fi
	return 0
}

# Probably a better way to do this, but whatevs.
#rand () {
#	echo $(php -r 'echo mt_rand();')
#}

#pickrand () {
#	cnt=0
#	if [ $# == 1 ]; then
#       tst=$1
#   else
#       tst="-d"
#   fi
#   for i in *; do
#       [ $tst "$i" ] && let 'cnt += 1'
#   done
#   r=$(rand)
#   p=0
#   [ $cnt -eq 0 ] && return 1
#   let 'p = r % cnt'
#   # echo "[$cnt $r --- $p]"
#   cnt=0
#   for i in *; do
#       # echo "[$cnt]"
#       [ $tst "$i" ] && let 'cnt += 1' && [ $cnt -eq $p ] && echo "$i" && return
#   done
# }


# md5 from the command line
# I like the BSD/Darwin "md5" util a bit better than md5sum flavor.
# Ported here to always have it.
# Yeah, that's right.  My bash profile has a PHP program embedded
# inside. You wanna fight about it?
# if ! inpath md5 && inpath php; then
#   # careful on this next trick. The php code can *not* use single-quotes.
#   echo  '<?php
#       // The BSD md5 checksum program, ported to PHP by Isaac Z. Schlueter
#       
#       exit main($argc, $argv);
#       
#       function /* int */ main ($argc, $argv) {
#           global $bin;
#           $return = true;
#           $bin = basename( array_shift($argv) );
#           $return = 0;
#           foreach (parseargs($argv, $argc) as $target => $action) {
#               // echo "$action($target)\n";
#               if ( !$action( $target ) ) {
#                   $return ++;
#               }
#           }
#           // convert to bash success/failure flag
#           return $return;
#       }
# 
#       function parseargs ($argv, $argc) {
#           $actions = array();
#           $getstring = false;
#           $needstdin = true;
#           foreach ($argv as $arg) {
#               // echo "arg: $arg\n";
#               if ($getstring) {
#                   $getstring = false;
#                   $actions[ "\"$arg\"" ] = "cksumString";
#                   continue;
#               }
#               if ($arg[0] !== "-") {
#                   // echo "setting $arg to cksumFile\n";
#                   $needstdin = false;
#                   $actions[$arg] = "cksumFile";
#               } else {
#                   // is a flag
#                   $arg = substr($arg, 1);
#                   if (strlen($arg) === 0) {
#                       $actions["-"] = "cksumFile";
#                   } else {
#                       while (strlen($arg)) {
#                           $flag = $arg{0};
#                           $arg = substr($arg, 1);
#                           switch ($flag) {
#                               case "s": 
#                                   if ($arg) {
#                                       $actions["\"$arg\""] = "cksumString";
#                                       $arg = "";
#                                   } else {
#                                       $getstring = true;
#                                   }
#                                   $needstdin = false;
#                               break;
#                               case "p": $actions[] = "cksumStdinPrint"; $needstdin = false; break;
#                               case "q": flag("quiet", true); break;
#                               case "r": flag("reverse",true); break;
#                               case "t": $actions["timeTrial"] = "timeTrial"; $needstdin = false; break;
#                               case "x": $actions["runTests"] = "runTests"; $needstdin = false; break;
#                               default : $actions["$flag"] = "usage"; $needstdin = false; break;
#                           } // switch
#                       } // while
#                   } // strlen($arg)
#               }
#           } // end foreach
#           if ($getstring) {
#               global $bin;
#               // exited without getting a string!
#               error_log("$bin: option requires an argument -- s");
#               usage();
#           }
#           if ($needstdin) {
#               $actions[] = "cksumStdin";
#           }
#           return $actions;
#       }
# 
#       /*
#       -s string
#           Print a checksum of the given string.
#       -p
#           Echo stdin to stdout and appends the MD5 sum to stdout.
#       -q
#           Quiet mode - only the MD5 sum is printed out.  Overrides the -r option.
#       -r
#           Reverses the format of the output.  This helps with visual diffs.
#           Does nothing when combined with the -ptx options.
#       -t
#           Run a built-in time trial.
#       -x
#           Run a built-in test script.
#       */
# 
#       function cksumFile ($file) {
#           $missing = !file_exists($file);
#           $isdir = $missing ? 0 : is_dir($file); // only call if necessary
#           if ( $missing || $isdir ) {
#               global $bin;
#               error_log("$bin: $file: " . ($missing ? "No such file or directory" : "is a directory."));
#               // echo "bout to return\n";
#               return false;
#           }
#           output("MD5 (%s) = %s", $file, md5(file_get_contents($file)));
#       }
#       function cksumStdin () {
#           $stdin = file_get_contents("php://stdin");
#           writeln(md5($stdin));
#           return true;
#       }
#       function cksumStdinPrint () {
#           $stdin = file_get_contents("php://stdin");
#           output("%s%s", $stdin, md5($stdin), array("reverse"=>false));
#           return true;
#       }
# 
#       function cksumString ($str) {
#           return output("MD5 (%s) = %s", $str, md5(substr($str,1,-1)));
#       }
#       function runTests () {
#           writeln("MD5 test suite:");
#           $return = true;
#           foreach (array(
#                   "", "a", "abc", "message digest", "abcdefghijklmnopqrstuvwxyz",
#                   "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
#                   "12345678901234567890123456789012345678901234567890123456789012345678901234567890") as $str ) {
#               $return = $return && cksumString("\"$str\"");
#           }
#           return $return;
#       }
#       function timeTrial () {
#           error_log("Time trial not supported in this version.");
#           return false;
#       }
#       function flag ($flag, $set = null) {
#           static $flags = array();
#           $f = in_array($flag, $flags) ? $flags[$flag] : ($flags[$flag] = false);
#           return ($set === null) ? $f : (($flags[$flag] = (bool)$set) || true) && $f;
#       }
#       
#       function usage ($option = "") {
#           global $bin;
#           if (!empty($option)) {
#               error_log("$bin: illegal option -- $option");
#           }
#           writeln("usage: $bin [-pqrtx] [-s string] [files ...]");
#           return false;
#       }
#       function output ($format, $input, $digest, $flags = array()) {
#           $orig_flags = array();
#           foreach ($flags as $flag => $value) {
#               $orig_flags[$flag] = flag($flag);
#               flag($flag, $value);
#           }
#           if ( flag("quiet") ) {
#               writeln($digest);
#           } elseif ( flag("reverse") ) {
#               writeln( "$digest $input" );
#           } else {
#               writeln( sprintf($format, $input, $digest) );
#           }
#           foreach ($orig_flags as $flag=>$value) {
#               flag($flag, $value);
#           }
#           return true;
#       }
#       function writeln ($str) {
#           echo "$str\n";
#       }
#   ?>'>~/bin/md5
#   shebang ~/bin/md5 php "-d open_basedir="
# fi

# a friendlier delete on the command line
! [ -d ~/.Trash ] && mkdir ~/.Trash
chmod 700 ~/.Trash
alias emptytrash="find ~/.Trash -not -path ~/.Trash -exec rm -rf {} \; 2>/dev/null"
if ! inpath del; then
	if [ -d ~/.Trash ]; then
		del () {
			for i in "$@"; do
				mv "$i" ~/.Trash/
			done
		}
	else
		alias del=rm
	fi
fi
alias mvsafe="mv -i"

lscolor=""
if [ "$TERM" != "dumb" ] && [ -f "$(which dircolors 2>/dev/null)" ]; then
	eval "$(dircolors -b)"
	lscolor=" --color=auto"
	#alias dir='ls --color=auto --format=vertical'
	#alias vdir='ls --color=auto --format=long'
fi
ls_cmd="ls$lscolor"
alias ls="$ls_cmd"
alias la="$ls_cmd -laFh"
alias lal="$ls_cmd -laFLh"
alias ll="$ls_cmd -lFh"
alias ag="alias | $grep"
fn () {
	func=$(set | egrep '^[a-zA-Z0-9_-]+ ()' | egrep -v '^_' | awk '{print $1}' | grep "$1")
	[ -z "$func" ] && echo "$1 is not a function" > /dev/stderr && return 1
	echo $func && return 0
}
alias lg="$ls_cmd -laF | $grep"
alias chdir="cd"
# alias more="less -e"
export MANPAGER=more
alias lsdevs="sudo lsof | $grep ' /dev'"


# domain sniffing
wh () {
	whois $1 | egrep -i '(registrar:|no match|record expires on|holder:)'
}



#make tree a little cooler looking.
alias tree="tree -CAFa -I 'CVS|rhel.*.*.package|.svn|.git' --dirsfirst"

if [ "$has_yinst" == 1 ]; then
	# echo "has yinst = $has_yinst"
	yapr="yinst restart yapache"
elif inpath lighttpd.wrapper; then
	yapr="sudo lighttpd.wrapper restart"
elif [ -f /etc/init.d/lighttpd ]; then
	yapr="sudo /etc/init.d/lighttpd reload"
elif inpath apache2ctl; then
	yapr="sudo apache2ctl graceful"
elif inpath apachectl; then
	yapr="sudo apachectl graceful"
else
	# very strange!
	yapr="echo Looks like lighttpd and apache are not installed."
fi
alias yapr="$yapr"


#error_log="$(choose_first /opt/local/var/log/lighttpd/error.log /home/y/logs/yapache/php-error /home/y/logs/yapache/error /home/y/logs/yapache/error_log /home/y/logs/yapache/us/error_log /home/y/logs/yapache/us/error /opt/local/apache2/logs/error_log /var/log/httpd/error_log /var/log/httpd/error)"
#yapl="tail -f $error_log | egrep -v '^E|udbClient'"
#alias yaprl="$yapr;$yapl"
#alias yapl="$yapl"

prof () {
	. ~/.extra.bashrc
}
editprof () {
	s=""
	if [ "$1" != "" ]; then
		s="_$1"
	fi
	$EDITOR ~/.extra$s.bashrc
	prof
}
pushprof () {
	[ "$1" == "" ] && echo "no hostname provided" && return 1
	failures=0
	rsync="rsync --copy-links -v -a -z"
	for each in "$@"; do
		if [ "$each" != "" ]; then
			if $rsync ~/.{inputrc,tarsnaprc,profile,extra,cvsrc,git}* $each:~ && \
					$rsync ~/.ssh/*{.pub,authorized_keys,config} $each:~/.ssh/; then
				echo "Pushed bash extras and public keys to $each"
			else
				echo "Failed to push to $each"
				let 'failures += 1'
			fi
		fi
	done
	return $failures
}

if [ $has_yinst == 1 ]; then
	alias inst="yinst install"
	alias yl="yinst ls"
	yg () {
		yinst ls | $grep "$@"
	}
	ysg () {
		yinst set | $grep "$@"
	}
elif [ -f "$(which port 2>/dev/null)" ]; then
	alias inst="sudo port install"
	alias yl="port list installed"
	yg () {
		port list '*'"$@"'*'
	}
	alias upup="sudo port sync && sudo port upgrade installed"
elif [ -f "$(which apt-get 2>/dev/null)" ]; then
	alias inst="sudo apt-get install"
	alias yl="dpkg --list | egrep '^ii'"
	yg () {
		dpkg --list | egrep '^ii' | $grep "$@"
	}
	alias upup="sudo apt-get update && sudo apt-get upgrade"
fi




alias sci="svn ci"
alias sg="svn up"
alias sq="svn status | egrep '^\?' | egrep -o '[^\?\ ].*$'"
alias sm="svn status -q"
alias svncleanup="sudo find . -name '.svn' -exec rm -rf {} \; ;"
pulltrunk () {
	if ! [ $(svn status -q | wc -l) -eq 0 ]; then
		echo "Unclean environment. Cannot safely pull from trunk."
		return 1
	fi
	trunk=$( svn info | grep '^URL:' | awk '{print $2}' | perl -pi -e 's/(branches|tags)\/[^\/]+/trunk/' )
	svn merge $trunk && svn up && svn ci -m "Merge from trunk"
}
__svn_ps1 () {
	[ -d $PWD/.svn ] return
	info="$(
		svn info | egrep -o '(tags|branches)/[^/]+|trunk' | head -n1 | egrep -o '[^/]+$'
	)"
	! [ -n "$info" ] && return
	[ -n "$1" ] && format="$1" || format=" %s "
	printf "$format" "$info"
}
# recursive grep with ignores.
gri () {
	grep -rs "$@" . | egrep -v '.svn/|CVS/'
}

alias gci="git commit"
alias gpu="git pull"
alias gps="git push --all"
gpm () {
	git pull $1 master
}

# look up a word
dict () {
	curl -s dict://dict.org/d:$1 | perl -ne 's/\r//; last if /^\.$/; print if /^151/../^250/' | more
}

#get the ip address of a host easily.
getip () {
	for each in "$@"; do
		echo $each
		echo "nslookup:"
		nslookup $each | grep Address: | grep -v '#' | egrep -o '([0-9]+\.){3}[0-9]+'
		echo "ping:"
		ping -c1 -t1 $each | egrep -o '([0-9]+\.){3}[0-9]+' | head -n1
	done
}

ips () {
	interface=""
	types='vmnet|en|eth'
	for i in $( ifconfig | egrep -o '(^('$types')[0-9]|inet (addr:)?([0-9]+\.){3}[0-9]+)' | egrep -o '(^('$types')[0-9]|([0-9]+\.){3}[0-9]+)' | grep -v 127.0.0.1 ); do
		# echo "i=[$i]"
		# if [ ${i:(${#i}-1)} == ":" ]; then
		if ! [ "$( echo $i | perl -pi -e 's/([0-9]+\.){3}[0-9]+//g' )" == "" ]; then
			interface="$i":
		else
			echo $interface $i
		fi
	done
}

macs () {
	interface=""
	for i in $( ifconfig | egrep -o '(^(vmnet|en)[0-9]:|ether ([0-9a-f]{2}:){5}[0-9a-f]{2})' | egrep -o '(^(vmnet|en)[0-9]:|([0-9a-f]{2}:){5}[0-9a-f]{2})' ); do
		# echo "i=[$i]"
		if [ ${i:(${#i}-1)} == ":" ]; then
			interface=$i
		else
			echo $interface $i
		fi
	done
}

# set the bash prompt and the title function

! [ "$TITLE" ] && TITLE=''
! [ "${__title}" ] && __title=''
__settitle () {
	__title="$1"
	if [ "$YROOT_NAME" != "" ]; then
		if [ "${__title}" != "" ]; then
			TITLE="$YROOT_NAME — ${__title}"
		else
			TITLE="$YROOT_NAME"
		fi
	else
		TITLE=${__title}
	fi
	DIR=${PWD/$HOME/\~}
	t=""
	[ "$TITLE" != "" ] && t="$TITLE — "
	echo -ne "\033]0;$t${HOSTNAME_FIRSTPART%%\.*}:$DIR\007"
}
title () {
	if [ ${#@} == 1 ]; then
		__settitle "$@"
	else
		echo "$TITLE"
	fi
}

#show the short hostname, selected title, and yroot, and update them all on each prompt
HOSTNAME=$(uname -n);
HOSTNAME_FIRSTPART=${HOSTNAME%\.yahoo\.com};
_arch=$(uname)
_bg=$([ $_arch == "Darwin" ] && echo 44 || echo 42)
_color=$([ $_arch == "Darwin" ] && echo 1 || echo 30)
PROMPT_COMMAND='history -a
__settitle "${__title}"
DIR=${PWD/$HOME/\~}
export HOSTNAME=$(uname -n)
export HOSTNAME_FIRSTPART=${HOSTNAME%\.yahoo\.com}
t=""
[ "$TITLE" != "" ] && t="$TITLE — "
echo ""
echo -ne "\033[0m\033]0;$t${HOSTNAME_FIRSTPART%%\.*}:$DIR\007"
[ "$TITLE" ] && echo -ne "\033[${_color}m\033[${_bg}m $TITLE \033[0m"
echo -ne "\033[1;41m ${HOSTNAME_FIRSTPART} \033[0m:$DIR \033[1;30m\033[40m$((__svn_ps1;__git_ps1 " %s ") 2>/dev/null)\033[0m"'
PS1='\n[\t \u] \\$ '
#this part gets repeated when you tab to see options
# \n[\t \u] \\$ "
# PS1=' '$PS1

# view processes.
alias processes="ps axMuc | egrep '^[a-zA-Z0-9]'"
pg () {
	ps aux | $grep "$@" | grep -v "$( echo $grep "$@" )"
}
pid () {
	pg "$@" | awk '{print $2}'
}

# alias v="ssh visitbread.corp.yahoo.com"
# alias vm="ssh visitbread-vm0.corp.yahoo.com"
# alias fh="ssh foohack.com"
# alias p="ssh isaacs.xen.prgmr.com"
# alias st="ssh sistertrain.com"


sshagents () {
	pg -i ssh
	set | grep SSH | grep -v grep
	find /tmp/ -type s | grep -i ssh
}
agent () {
	eval $( ssh-agent )
	ssh-add
}

vazu () {
	rsync -vazuR --stats --no-implied-dirs --delete --exclude=".*\.svn.*" "$@"
}

# fhcp () {
# 	p="$PWD"
# 	for i in "$@"; do
# 		if [ -d "$p/$i" ] || [ -f "$p/$i" ]; then
# 			dir=$(dirname "$p/$i")
# 			siteroot=~/Sites/
# 			rdir=${dir##$siteroot}
# 			echo "Sending $i"
# 			vazu $i foohack.com:~/apache/$rdir
# 		fi
# 	done
# }
# 
# fhfetch () {
# 	p="$PWD"
# 	for i in "$@"; do
# 		dir=$(dirname "$p/$i")
# 		siteroot=~/Sites
# 		# siteroot=$siteroot
# 		# dir=$dir
# 		rdir=${dir##$siteroot}
# 		# echo rdir=$rdir
# 		file=$(basename "$i")
# 		# file=$file
# 		rsync -vazu --no-implied-dirs --stats --exclude=".*\.svn.*" foohack.com:~/apache$rdir/$file $dir/
# 		#scp -r foohack.com:~/apache$rdir/$file $dir
# 	done
# }


repeat () {
	if [ "$2" == "" ]; then
		delay=1
	else
		delay=$2
	fi
	while sleep $delay; do
		clear
		date +%s
		$1
	done
}

# floating-point calculations
calc () {
	expression="$@"
	[ "${expression:0:6}" != "scale=" ] && expression="scale=16;$expression"
	echo "$expression" | bc
}

# more persistent wget for fetching files to a specific filename.
fetch_to () {
	[ $# -ne 2 ] && echo "usage: fetch_to <url> <filename>" && return 1
	urltofetch=$1
	fname="$2"
	wget -U "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.0.5) Gecko/2008120121 Firefox/3.0.5" -O "$fname" $urltofetch
}

# command-line perl prog
alias pie="perl -pi -e "

# c++ compile
stripc () {
	f="$1"
	o="$f"
	o=${o%.c}
	o=${o%.cpp}
	o=${o%.cc}
	echo $o
}
cm () {
	g++ -o $(stripc "$1") "$1"
}
cr () {
	cm "$1" && ./$(stripc "$1")
}

# tarsnap wrappers.
# http://tarsnap.com
# ts () {
#   e=echo
#   inpath growlnotify && e="growlnotify -t tarsnap -m "
#   if [ $# -lt 1 ] || ! [ -e "$1" ]; then
#       $e "Need to supply a file/directory to back up" > /dev/stderr
#       return 1
#   fi
#   if [ $# -gt 1 ]; then
#       errors=0
#       for i in "$@"; do
#           ts $i || let 'errors += 1'
#       done
#       return $errors
#   fi
#   thetitle=$(title)
#   thefile="$1"
#   $e "backing up $thefile"
#   title "backing up $thefile"
#   backupfile="$(hostname):${thefile/\//}:$(date +%Y-%m-%d-%H-%M-%S)"
#   backupfile=${backupfile//\//-}
#   tarsnap -cvf "$backupfile" $thefile 2> ~/.tslog
#   $e "done backing up $thefile"
#   title "$thetitle"
# }
# tsbg () {
#   ( ts "$@" ) &
# }
# tsh () {
#   # headless <command> [<key>]
#   headless "ts $@" ts-headless-backup
# }
# tskill () {
#   kill -s SIGQUIT $(pid tarsnap)
# }
# tsabort () {
#   kill $(pid tarsnap)
# }
# tslisten () {
#   tail -f ~/.tslog
# }
# tsl () {
#   tslisten
# }


#load any per-platform .extra.bashrc files.
arch=$(uname -s);
[ -f ~/.extra_$arch.bashrc ] && . ~/.extra_$arch.bashrc
machinearch=$(uname -m)
[ -f ~/.extra_${arch}_${machinearch}.bashrc ] && . ~/.extra_${arch}_${machinearch}.bashrc
[ $has_yinst == 1 ] && [ -f ~/.extra_yinst.bashrc ] && . ~/.extra_yinst.bashrc
inpath "git" && [ -f ~/.git-completion ] && . ~/.git-completion

export BASH_EXTRAS_LOADED=1