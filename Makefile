.PHONY: build test run release package dmg downloads localizations format lint security verify app-store clean

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

downloads:
	bash Scripts/package-downloads.sh

localizations:
	swift Scripts/generate-localizations.swift

format:
	swift format --in-place --recursive Sources Tests Package.swift

lint:
	swift format lint --recursive --strict Sources Tests Package.swift
	bash -n Scripts/*.sh

security:
	bash Scripts/check-secrets.sh

verify: localizations lint security test package
	bash Scripts/verify-app.sh

app-store:
	bash Scripts/package-app-store.sh

clean:
	swift package clean
	rm -rf dist
