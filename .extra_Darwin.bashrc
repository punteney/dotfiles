# commands that only get loaded on the Darwin platform.
# Mostly, these commands interact with specific Mac programs.

[ $(basename "$EDITOR") == "mate_wait" ] && export LESSEDIT='mate_wait -l %lm %f'


