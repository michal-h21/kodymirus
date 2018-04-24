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
local render_permalinks = require "lettersmith.permalinks".render_permalinks
local wrap_in_iter = require("lettersmith.plugin_utils").wrap_in_iter


local take_while = transducers.take_while
local take = transducers.take
local into = transducers.into


-- variables 
local site_url = "https:www.kodymirus.cz"
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

local rss_gen = function(page, title, url)
  local title = title or site_title
  local url = url or site_url
   return comp(
   rss.generate_rss(page,url,title, ""),
   abstract_to_content,
   render_permalinks ":yyyy/:mm/:slug.html",
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
  render_permalinks ":yyyy/:mm/:slug.html",
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
  local items = {{relative_filepath = "wtf1", contents="wtf1"}, {relative_filepath = "wtf2", contents="wtf2"}}
  return function(iter, ...)
    return coroutine.wrap(function()
      for _,v in ipairs(items) do
        coroutine.yield(v)
      end
    end)
  end
end

local take_all_items = comp(take(10), map(function(doc) return {category=doc.category} end))
local category_wtf = function()
  return function(iter, ...)
    local items =  {}
    local items = into(take_all_items,iter, ...)
    for _, x in ipairs(items) do
      print(x.category)
    end

  end
end


 
-- build pages
lettersmith.build(
  "www", -- output dir
  builder(paths), -- process all files
  wtf()(paths),
  html_builder(paths), -- process only html files
  category_wtf()(paths),
  category_rss("pokus")(paths),
  category_rss("nonpokus")(paths),
  make_rss("feed.rss",  "Kodymirus","https://www.kodymirus.cz")(paths)
)

