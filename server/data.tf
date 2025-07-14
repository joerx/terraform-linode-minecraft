locals {
  # Any better way to do this?
  minecraft_download_urls = {
    "1.19.3" = "https://piston-data.mojang.com/v1/objects/c9df48efed58511cdd0213c56b9013a7b5c9ac1f/server.jar"
    "1.19.4" = "https://piston-data.mojang.com/v1/objects/8f3112a1049751cc472ec13e397eade5336ca7ae/server.jar"
    "1.21.7" = "https://piston-data.mojang.com/v1/objects/05e4b48fbc01f0385adb74bcff9751d34552486c/server.jar"
  }

  minecraft_port = "25565"
  ssh_port       = "22"
}
