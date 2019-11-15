package.path = "?.lua;src/?.lua;"..package.path
local lettersmith = require("lettersmith")
local transducers = require "lettersmith.transducers"
-- local rss = require "atom"
local map = transducers.map
local reduce = transducers.reduce
local filter  = transducers.filter
local lazy = require "lettersmith.lazy"
local merge = require("lettersmith.table_utils").merge
local transform = lazy.transform
local transformer = lazy.transformer
local templates = require "template"
local base_template = templates.base
local rss = require "lettersmith.rss"
local rss_table = require "rss".rss_table
local render_permalinks = require "lettersmith.permalinks".render_permalinks
local wrap_in_iter = require("lettersmith.plugin_utils").wrap_in_iter
local archive = require "archive".archive
local config = require "config"



local take_while = transducers.take_while
local take = transducers.take
local into = transducers.into

local shallow_copy = require "lettersmith.table_utils".shallow_copy

-- variables
local site_url = config.site_url 
local site_title = config.site_title 
local site_description = config.site_description  
-- number of items in the RSS feed
local rss_count = 20
-- number of items on the index page
local index_count = 5

local paths = lettersmith.paths("build")
local comp = require("lettersmith.transducers").comp

-- local render_mustache = require("lettersmith.mustache").choose_mustache

local make_transformer = function(fn)
  return transformer(map(fn))
end

local make_filter = function(reg)
  return transformer(filter(function(doc)
    local fn = doc.relative_filepath
    return fn:match(reg)
  end
  ))
end

local make_negative_filter = function(reg)
  return transformer(filter(function(doc)
    local fn = doc.relative_filepath
    return not fn:match(reg)
  end
  ))
end

local post_filter = transformer(filter(function(doc)
  return doc.layout == "post"
end))


local html_filter = make_filter("html$")
local nonhtml_filter = make_negative_filter("html$")

local add_defaults = make_transformer(function(doc)
  -- potentially add default variables
  doc.menu = config.menu
  return doc
end)

local apply_template = make_transformer(function(doc)
  local template = templates[doc.template] or base_template
  local rendered = template(doc)
  return merge(doc, {contents = rendered})
end)

-- move abstract to content for RSS feeds or archives
local abstract_to_content = make_transformer(function(doc)
  local newcontent = doc.abstract or doc.contents
  return merge(doc, {contents = newcontent})
end)


local permalinks = comp (
   render_permalinks ":yyyy/:mm/:slug.html"
)

-- prepare list of posts for archives or RSS
local archives = comp(
  permalinks,
  post_filter, -- show only posts in archives
  html_filter
)

local builder = comp(
  nonhtml_filter,
  lettersmith.docs
)
local html_builder = comp(
  apply_template,
  permalinks,
  add_defaults,
  html_filter,
  lettersmith.docs
)


local make_index = function(name)
  -- take latest posts and compile them to a table
  local take_news = comp(take(index_count), map(function(doc) return doc end)) 
  return function(iter, ...)
    local items = into(take_news, iter, ...)
    return wrap_in_iter 
    {
      title = site_title,
      relative_filepath = name,
      items = items,
      contents = "",
      template = "index"
    }
  end
end

local index_builder = comp(
  apply_template,
  make_index("index.html"),
  permalinks,
  add_defaults,
  html_filter,
  lettersmith.docs
)


-- transform document iterator into table
local function take_items(criterium)
  return comp(take_while(criterium),map(function(doc) return shallow_copy(doc) end))
end


local categories_to_rss = function(count)
  return transformer(map(function(doc)
    local feed_name = doc.category ..".rss"
    return merge(doc, {
      relative_filepath = feed_name,
      contents = rss_table(doc.items, feed_name, site_url, site_title,site_description,  count)
    })
  end))
end



local categories = function()
  return function(iter, ...)
    -- local items =  {}
    local categories = {}

    local items = into(take_items(function() return true end),iter, ...)
    for _, x in ipairs(items) do
      local category = x.category or "uncatagorized"
      local curr = categories[category] or {}
      table.insert(curr, x)
      categories[category] = curr
    end
    return coroutine.wrap(function()
      for x, y in pairs(categories) do
        coroutine.yield {category = x, items = y}
      end
    end)
  end
end


local main_rss = function()
  return function(iter, ...)
    local items = into(take_items(function() return true end),iter, ...)
    return coroutine.wrap(function()
      coroutine.yield {category="feed", items = items}
    end)
  end
end


local make_main_rss = comp(
  categories_to_rss(rss_count),
  main_rss(), -- this make only one category, "feed", which is then saved as feed.rss
  abstract_to_content, -- don't show full posts
  archives,
  lettersmith.docs
)

local category_rss_build = comp(
  categories_to_rss(rss_count),
  categories(),
  abstract_to_content, -- don't show full posts
  archives,
  lettersmith.docs
)


-- build pages
lettersmith.build(
  "www", -- output dir
  index_builder(paths),
  builder(paths), -- process all files
  html_builder(paths), -- process only html files
  category_rss_build(paths),
  -- category_rss("pokus")(paths),
  -- category_rss("nonpokus")(paths),
  -- archive("feed.rss",  "Kodymirus","https://www.kodymirus.cz")(paths),
  make_main_rss(paths)
)

