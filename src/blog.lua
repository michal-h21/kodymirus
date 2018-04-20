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

local html_filter = make_filter("html$")

local add_defaults = make_transformer(function(doc)
  -- potentially add default variables
  return doc
end)

local apply_template = make_transformer(function(doc)
  local rendered = base_template(doc)
  return merge(doc, {contents = rendered})
end)

local rss_gen = function(page, title)
   return comp(
   rss.generate_rss(page,"https://www.kodymirus.cz",title, ""),
   html_filter,
   lettersmith.docs
  )
end

local builder = comp(lettersmith.docs)
local html_builder = comp(
  apply_template,
  add_defaults,
  html_filter,
  lettersmith.docs
)


lettersmith.build("www", builder(paths), html_builder(paths),rss_gen("feed.rss",  "Kodymirus")(paths))

