-- helper function for simpler menu items
local menuitem = function(title, href) return {title = title, href= href} end
-- add defaults
return {
  menu = {
    menuitem("Home", "/index.html"),
    menuitem("Now", "/now.html")
  },
  site_url = "https://www.kodymirus.cz",
  site_title = "Kodymirus",
  site_author = "Michal Hoftich",
  site_author_email = "michal.h21@gmail.com",
  site_description = "Kodymirus blog", 
  path = "build",
  output_dir = "www",
  author_profile = "https://github.com/michal-h21",
  language="en",
  about="/now" -- address of the about page
}
