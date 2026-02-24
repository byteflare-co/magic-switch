cask "magic-switch" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/byteflare-co/magic-switch/releases/download/v#{version}/MagicSwitch-#{version}.zip"
  name "Magic Switch"
  desc "Switch Magic Keyboard and Trackpad between Macs with one click"
  homepage "https://github.com/byteflare-co/magic-switch"

  depends_on macos: ">= :ventura"

  app "MagicSwitch.app"

  postflight do
    system_command "/bin/chmod",
                   args: ["+x", "#{appdir}/MagicSwitch.app/Contents/Resources/blueutil"],
                   sudo: false
  end

  uninstall quit: "com.magicswitch.app"

  zap trash: [
    "~/Library/Application Support/MagicSwitch",
    "~/Library/Logs/MagicSwitch",
    "~/Library/Preferences/com.magicswitch.app.plist",
  ]
end
