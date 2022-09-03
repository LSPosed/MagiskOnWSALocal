# How to install custom OpenGApps

1. Build WSA without gapps to let the script download needed files

    `./build.sh --gapps-brand none`
1. Place custom OpenGApps to `download` folder and rename to `OpenGApps-{arch}-{variant}.zip` (e.g. `OpenGApps-x64-pico.zip`)
1. Build WSA offline

    `./build.sh --offline --gapps-variant {variant}`
