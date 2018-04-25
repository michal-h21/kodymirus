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



local take_while = transducers.take_while
local take = transducers.take
local into = transducers.into

local shallow_copy = require "lettersmith.table_utils".shallow_copy

-- variables 
local site_url = "https://www.kodymirus.cz"
local site_title = "Kodymirus"

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

local category_filter = function(category) 
  return transformer(filter(function(doc)
    return doc.category == category
  end))
end

local html_filter = make_filter("html$")
local nonhtml_filter = make_negative_filter("html$")

local add_defaults = make_transformer(function(doc)
  -- potentially add default variables
  return doc
end)

local apply_template = make_transformer(function(doc)
  local rendered = base_template(doc)
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

local rss_gen = function(page, title, url)
  local title = title or site_title
  local url = url or site_url
   return comp(
   rss.generate_rss(page,url,title, ""),
   permalinks,
   abstract_to_content,
   html_filter
  )
end

local make_rss = function(page)
  return comp(
    rss_gen(page),
    lettersmith.docs
  )
end




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

local category_rss = function(category)
  return comp(
     rss_gen(category .. ".rss"),
     category_filter(category),
     lettersmith.docs
  )
end

local wtf = function()
  local items = {{relative_filepath = "wtf1", contents="wtf1"}, {relative_filepath = "wtf2", contents="wtf2"}, {relative_filepath = "wtf3", contents="wtf2"}}
  return function(iter, ...)
    -- for x,y in pairs(iter) do
    --   local fn = lettersmith.load_doc(y)
    --   print("doc", fn, x, y)
    --   print(fn.category)
    -- end
    -- local items = lettersmith.docs(iter, ...)
    -- local items = into(take_all_items,iter, ...)
    return coroutine.wrap(function()
      for _,v in ipairs(items) do
        print("wtf", v)
        coroutine.yield(v)
      end
    end)
  end
end


local category_rss = function()
  local function xxx(doc)
    return shallow_copy(doc)
  end
  local take_all_items = comp(
    take_while(function()return true end),
    map(xxx)
  )
  return function(iter, ...)
    -- local items =  {}
    local categories = {}
    local items = into(take_all_items,iter, ...)
    for _, x in ipairs(items) do
      local category = x.category
      local curr = categories[category] or {}
      table.insert(curr, x)
      categories[category] = curr
    end
    return coroutine.wrap(function()
      -- coroutine.yield({relative_filepath="uggggg", contents= "adfsff"})
      for x, y in pairs(categories) do
        print("writing", x)
        local feed_name = x.. ".rss"
        coroutine.yield {relative_filepath = feed_name, contents= rss_table(y, feed_name, site_url, site_title)}
      end
    end)
  end
end

local category_rss_build = function()
  return comp(
    category_rss(),
    permalinks,
    html_filter,
    lettersmith.docs
  )
end


 
-- build pages
lettersmith.build(
  "www", -- output dir
  builder(paths), -- process all files
  wtf()(paths),
  html_builder(paths), -- process only html files
  category_rss_build()(paths),
  -- category_rss("pokus")(paths),
  -- category_rss("nonpokus")(paths),
  -- archive("feed.rss",  "Kodymirus","https://www.kodymirus.cz")(paths),
  make_rss("feed.rss",  "Kodymirus","https://www.kodymirus.cz")(paths)
)

