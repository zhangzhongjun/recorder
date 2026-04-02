.PHONY: build dmg run clean

## Build the app bundle (Recorder.app)
build:
	bash build.sh

## Package into a distributable DMG
dmg: build
	bash make_dmg.sh

## Build and launch immediately
run: build
	open Recorder.app

## Remove build artifacts
clean:
	rm -rf .build Recorder.app Recorder.dmg .tmp_*.dmg .dmg_background.png
