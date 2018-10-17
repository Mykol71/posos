EBW=$(wildcard easybashweb_[0-9].[0-9].[0-9])
install:
	@echo Installing ${EBW} ...
	cp ${EBW} Ok.xpm Attenzione.xpm urldecode /usr/local/bin/
	chmod 755 /usr/local/bin/${EBW}
	chmod 755 /usr/local/bin/urldecode
	ln -sf /usr/local/bin/${EBW} /usr/local/bin/easybashweb
	@echo "=> Installed."