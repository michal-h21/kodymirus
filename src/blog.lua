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
local base_template = templates.post -- blog entry template
-- we use our own version of the rss library from lettersmith
-- local rss = require "lettersmith.rss"
local rss_table = require "rss".rss_table
local generate_atom = require "atom".generate_atom
local render_permalinks = require "lettersmith.permalinks".render_permalinks
local wrap_in_iter = require("lettersmith.plugin_utils").wrap_in_iter
local comp = require("lettersmith.transducers").comp
local paging = require "lettersmith.paging"
-- it seems that this isn't used anymore:
-- local archive = require "archive".archive
local config = require "config"

local checksum = require "plc.checksum"



local into = transducers.into

local shallow_copy = require "lettersmith.table_utils".shallow_copy

local take_while = transducers.take_while
local take = transducers.take


-- variables
local site_url = config.site_url 
local site_title = config.site_title 
local site_description = config.site_description  
local site_author = config.site_author
local author_profile = config.author_profile
-- number of items in the RSS feed
local rss_count = config.rss_count or 20
-- number of items on the index page
local index_count = config.index_count or 5
local blog_path = arg[1] or config.path or "build"
local pages_path = arg[2] or config.pages_path or "pages"
local notes_path = arg[3] or config.notes_path or "notes"
print("Notes path is: " .. notes_path)
local output_dir = config.output_dir or "www"
local uncategorized = config.uncategorized or "uncategorized"
local language = config.language or "en"
local about_page = config.about or "/now"

local paths = lettersmith.paths(blog_path)
local pages = lettersmith.paths(pages_path)
local notes = lettersmith.paths(notes_path)


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

local function parse_datetime(str)
  if not str then return nil end
  local year, month, day, hour, min = str:match("(%d+)%-(%d+)%-(%d+)%s+(%d+):(%d+)")
  return os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = 0,
  })
end

local add_defaults = make_transformer(function(doc)
  -- potentially add default variables
  doc.menu = config.menu
  doc.site_url = site_url
  doc.site_title = site_title
  doc.author = doc.author or site_author
  -- doc.feed = "feed.rss"
  doc.feed = "feed.xml"
  doc.layout = doc.layout or "page"
  doc.category = doc.category or uncategorized
  doc.category_feed = doc.category .. ".xml"
  doc.styles = doc.styles or {}
  -- if #doc.styles  == 0 then
    -- add default style
    table.insert(doc.styles, "/style.css")
  -- end
  doc.time = doc.time or parse_datetime(doc.timestamp) or os.time()
  doc.date = doc.date or os.date("%Y-%m-%d", doc.time)
  doc.author = doc.author or site_author
  doc.author_profile = author_profile
  doc.about_page = about_page
  doc.language = language
  return doc
end)

local apply_template = make_transformer(function(doc)
  local template = templates[doc.template] or base_template
  print("Applying template '" .. (doc.template or "post") .. "' to " .. doc.relative_filepath)
  local rendered = template(doc)
  return merge(doc, {contents = rendered})
end)

-- move abstract to content for RSS feeds or archives
local abstract_to_content = make_transformer(function(doc)
  local newcontent = doc.abstract or doc.contents
  return merge(doc, {contents = newcontent})
end)

local function save_checksums(iter)
  local checksum_table = {}
  return coroutine.wrap(function()
    -- calculate crc32 for each document
    for doc in iter do
      checksum_table[doc.relative_filepath] = doc.checksum
      coroutine.yield(doc)
    end

    -- save checksums in tab separate file
    local filename = config.checksum_file or  "checksums.tsv"
    local f = io.open(filename, "w")
    for k,v in pairs(checksum_table) do
      f:write(k .. "\t" .. v .."\n")
    end
    f:close()
  end)
end
      


local calc_hash = make_transformer(function(doc)
  local hash = checksum.crc32(doc.contents)
  return merge(doc, {checksum = hash})
end)


-- transform document iterator into table
local function take_items(criterium)
  return comp(take_while(criterium),map(function(doc) return shallow_copy(doc) end))
end

-- transform number of documents into table
local function take_number(index_count)  
  return comp(take(index_count), map(function(doc) return shallow_copy(doc) end)) 
end

local copy_doc = make_transformer(function(doc)
  return shallow_copy(doc)
end)

local permalinks = comp (
   render_permalinks "/blog/:yyyy-:mm-:slug.html"
)


local note_permalink = comp (
   render_permalinks "/notes/:yyyy-:mm-:dd-:slug.html"
)

-- prepare list of posts for archives or RSS
local archives = comp(
  permalinks,
  add_defaults,
  post_filter, -- show only posts in archives
  html_filter
)

local builder = comp(
  nonhtml_filter,
  lettersmith.docs
)


local html_prepare = comp(
  permalinks,
  add_defaults,
  html_filter,
  lettersmith.docs
)

local html_builder = comp(
  apply_template,
  save_checksums, 
  calc_hash,
  html_prepare
)

local note_archive_page_count = 0

--- count number of pages in the note archive
for doc in lettersmith.docs(notes) do
  -- this counts total number of notes
  note_archive_page_count = note_archive_page_count + 1
end

config.posts_per_page = 1

local total_note_archive_pages = math.ceil(note_archive_page_count / (config.posts_per_page or 10))


local use_note_archive_template = make_transformer(function(doc)
  -- use blog archive template for blog archive pages
  print("Using blog archive template for page " .. doc.page_number, total_note_archive_pages)
  doc.template = "note_archive"
  local title_template = config.note_archive_title_template or "Notes - Page :n"
  title_template = title_template:gsub(":n", doc.page_number)
  print("next page path", doc.next_page_path)
  doc.total_pages = total_note_archive_pages
  doc.title = title_template
  return doc
end)



-- make archive of notes with paging
local note_archive = comp(
  apply_template, 
  use_note_archive_template,
  add_defaults,
  paging("/notes/:n/index.html", config.posts_per_page or 10),
  -- paging("/notes/:n/index.html", 2),
  note_permalink,
  add_defaults,
  html_filter,
  lettersmith.docs
)

local use_note_post_template = make_transformer(function(doc)
  -- use note template for notes
  doc.template = "note_post"
  return doc
end)

local note_title = make_transformer(function(doc)
  -- some notes may not have title, we need to add a dummy title then
  local template = config.note_title_template or "Note published on :humandate"
  -- replace variables in the template
  local new_title = template:gsub(":([%w%_%-]+)", doc)
  doc.title = doc.title or new_title
  return doc
end)

local note_post = comp(
  apply_template, 
  -- use_note_archive_template,
  -- add_defaults,
  use_note_post_template,
  note_title,
  note_permalink,
  add_defaults,
  -- html_filter,
  lettersmith.docs
)


local use_pages_template = make_transformer(function(doc)
  -- use page template for pages
  doc.template = "page"
  return doc
end)

-- process static pages inthe pages directory
-- we don't need to add permalinks here
local page_builder = comp(
  apply_template,
  use_pages_template,
  add_defaults,
  html_filter,
  lettersmith.docs
)


-- index page generation
local make_index = function(name, index_count, template, note_archive_docs)
  -- take latest posts and compile them to a table
  return function(iter, ...)
    local items 
    if index_count then
      items = into(take_number(index_count), iter, ...)
    else
      items = into(take_items(function() return true end),iter, ...)
    end
    return wrap_in_iter 
    {
      title = site_title,
      relative_filepath = name,
      items = items,
      contents = "",
      template = template,
      notes = note_archive_docs or {}
    }
  end
end


-- local index_builder = comp(
--   apply_template,
--   make_index("index.html"),
--   archives,
--   lettersmith.docs
-- )
--


local main_archive_builder = function(filename, template, count, notes)
  local note_archive_docs = {}
  -- I want to show both blog posts and notes on the index page. notes can be iterator created by lettersmith.docs
  -- if present, I will copy them to a table that will be available in the index document, so it can be used in templates
  if notes then
    local notes_docs = lettersmith.docs(notes)
    local i = 1
    for doc in notes_docs do
      if i > count then break end
      local newdoc = shallow_copy(doc)
      -- we must add default dates
      newdoc.time = newdoc.time or parse_datetime(doc.timestamp) or os.time()
      table.insert(note_archive_docs, newdoc)
    end
  end
  return comp(
  apply_template, 
  add_defaults,
  make_index(filename, count, template, note_archive_docs),
  archives,
  lettersmith.docs
  )
end

local index_builder = main_archive_builder("index.html", "index", index_count, notes)
local archive = main_archive_builder("archive.html", "archive")


-- process posts and save them under categories
local categories = function()
  return function(iter, ...)
    -- local items =  {}
    local categories = {}

    local items = into(take_items(function() return true end),iter, ...)
    for _, x in ipairs(items) do
      local category = x.category or uncategorized 
      local curr = categories[category] or {}
      table.insert(curr, shallow_copy(x))
      categories[category] = curr
    end
    return coroutine.wrap(function()
      for x, y in pairs(categories) do
        coroutine.yield {category = x, items = y}
      end
    end)
  end
end

local categories_archive = function(title, filename, template)
  -- generate page with list of all posts by category
  return function(iter, ...)
    -- iterator contains particular categories
    local categories = {}
    -- fetch all categories
    local items = into(take_items(function() return true end),iter, ...)
    for i, x in ipairs(items) do
      local category = x.category or uncategorized
      categories[i] = {name = category, items = x.items}
    end
    -- sort categories alphabetically
    table.sort(categories, function(a,b) return a.name < b.name end)
    return wrap_in_iter {relative_filepath = filename, title = title, categories = categories, template = template}
  end
end

local categories_archive_builder = comp(
  apply_template,
  add_defaults,
  categories_archive("Archive by category", "category-archive.html", "categoryarchive"),
  categories(),
  copy_doc,
  archives,
  lettersmith.docs
)


local categories_to_rss = function(count)
  return transformer(map(function(doc)
    local feed_name = doc.category ..".xml"
    return merge(doc, {
      relative_filepath = feed_name,
      -- contents = rss_table(doc.items, feed_name, site_url, site_title,site_description,  count)
      contents = generate_atom(doc.items, feed_name, site_url, site_title,site_description,  count, site_author, config.site_author_email )
    })
  end))
end





local main_rss = function(category)
  return function(iter, ...)
    local items = into(take_items(function() return true end),iter, ...)
    return coroutine.wrap(function()
      coroutine.yield {category= category or "feed", items = items}
    end)
  end
end


local make_main_rss = comp(
  categories_to_rss(rss_count),
  main_rss(), -- this make only one category, "feed", which is then saved as feed.rss
  -- it is better to show full posts, actually
  -- abstract_to_content, -- don't show full posts
  archives,
  copy_doc,
  lettersmith.docs
)

local category_rss_build = comp(
  categories_to_rss(rss_count),
  categories(),
  -- it is better to show full posts, actually
  -- abstract_to_content, -- don't show full posts
  archives,
  copy_doc,
  lettersmith.docs
)

local note_rss = comp(
  categories_to_rss(rss_count),
  main_rss("notes"), -- this make only one category, "notes", which is then saved as notes.rss
  -- it is better to show full posts, actually:
  -- abstract_to_content, -- don't show full posts
  -- archives,
  note_permalink,
  note_title,
  -- to avoid setting title in original document, we need it to be empty in the note archive page. 
  -- if we didn't copy it in this transformation, it would be set also in other transformatins:
  copy_doc,
  add_defaults,
  html_filter,
  lettersmith.docs
)



-- build pages
lettersmith.build(
  output_dir, -- output dir
  index_builder(paths),
  note_archive(notes),
  note_rss(notes),
  note_post(notes),
  page_builder(pages),
  archive(paths),
  categories_archive_builder(paths),
  builder(paths), -- process all files
  html_builder(paths), -- process only html files
  category_rss_build(paths),
  -- category_rss("pokus")(paths),
  -- category_rss("nonpokus")(paths),
  -- archive("feed.rss",  "Kodymirus","https://www.kodymirus.cz")(paths),
  make_main_rss(paths)
)

