(Don't judge me for my horrible varaiable naming if you read the script ('_') )

Just Run the script and go through the options

To-Be-Done:

	1) Auto-Install Menu:
		 i) Fresh Auto Install
		ii) MultiBoot Auto Install

	2) Bootloaders
		   i) syslinux
		  ii) refind
		 iii) systemd-boot (bootctl)

	3) shell rc files
		  i) bashrc prompts for stronger machines (A mix of conf files, python scripts, bash scripts just to make it look like those prompts you see with git icons and colorfilled text embeded arrows. not advisable to be used on weak machines though it can be used)
			ii) zshrc prompts as the one above.

	4) partition editor
		   i) include manual editing on the dialog iface (parted will be used to partition the disk)
		  ii) include auto partition

	5) set default locale as english based on the tz selected if locale is not set. if tz (and/or) locale is not selected then prompt to select tz first (if not selected) then prompt for locale selection
