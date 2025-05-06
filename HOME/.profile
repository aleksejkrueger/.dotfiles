# Start zsh if available and we're not already in it
if [ -x /bin/zsh ] && [ "$SHELL" != "/bin/zsh" ]; then
	    exec /bin/zsh
fi
