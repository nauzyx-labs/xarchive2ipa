BINARY_NAME=xarchive2ipa
INSTALL_PATH=/usr/local/bin/$(BINARY_NAME)

build:
	swiftc main.swift -o $(BINARY_NAME) -O

install: build
	sudo mv $(BINARY_NAME) $(INSTALL_PATH)
	@echo "Successfully installed to $(INSTALL_PATH)"

clean:
	rm -f $(BINARY_NAME)
