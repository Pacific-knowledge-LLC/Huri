.PHONY: build test run release package dmg clean

build:
	swift build

test:
	swift test

run:
	swift run HuriApp

release:
	swift build -c release

package:
	bash Scripts/package-app.sh

dmg: package
	bash Scripts/create-dmg.sh

clean:
	swift package clean
	rm -rf dist
