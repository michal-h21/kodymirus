-- helper function for simpler menu items
local menuitem = function(title, href) return {title = title, href= href} end
-- add defaults
return {
  menu = {
    menuitem("Home", "index.html")
  }

}
