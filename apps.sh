source ./util.sh

source .configrc

current_app=""

install_app() {
  brew install --cask "$current_app"
}


install_apps() {
for app in "${apps[@]}"; do  
  current_app=$app
  command_exists "brew list --cask --force $app" noop install_app app
done

}

install_apps
