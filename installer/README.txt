AgeVerificationBypass - installer
================================

needs a vencord source checkout with pnpm install done:

  git clone https://github.com/Vendicated/Vencord.git C:\Vencord
  cd C:\Vencord
  pnpm install

run
  INSTALL.cmd
  type the checkout path when asked

it builds the plugin in, backs up your vencord files, swaps them and reopens whatever client was
running. then enable AgeVerificationBypass in settings - vencord - plugins

undo
  UNINSTALL.cmd restores the backup
  no backup? run the vencord installer - repair

heads up
  - vencord or discord updates replace the patched files, run install again
  - mods = against discord tos, ban risk is yours
