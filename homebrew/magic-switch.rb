cask "magic-switch" do
  version "1.1.2"
  sha256 "483b7b68375e1bb719a6dbe2de678676c22b084675c64c390521d448040a9d01"

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
