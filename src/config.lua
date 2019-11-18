-- helper function for simpler menu items
local menuitem = function(title, href) return {title = title, href= href} end
-- add defaults
return {
  menu = {
    menuitem("Home", "index.html"),
    menuitem("Now", "now.html")
  },
  site_url = "https://www.kodymirus.cz",
  site_title = "Kodymirus",
  site_author = "Michal Hoftich",
  site_description = "Kodymirus blog", 
  path = "build",
  output_dir = "www"
}
