local h5tk = require "h5tk"
local os = require "os"
local date = require "date"

local template = {}

local h = h5tk.init(true)
local html, head, body, title, link, article = h.html, h.head, h.body, h.title, h.link, h.article

local function map(func, tbl)
  local newtbl = {}
  for i,v in pairs(tbl) do
    newtbl[i] = func(v)
  end
  return newtbl
end

local function human_date(time)
  local d = date(time)
  -- format as month-name day, year
  return d:fmt("%B %d, %Y"):gsub(" 0", " ") -- days smaller than 10 contain leading zero, delete it
end

local function archive_item(item)
  return h.p{os.date( "%Y-%m-%d", item.time ), h.a {href=item.relative_filepath, item.title}}
end

local function styles(s)
  local s = s or {}
  local t = {}
  for _, style in ipairs(s) do
    table.insert(t, link {rel="stylesheet", type="text/css", href=style})
  end
  return t
end

function root(doc)
  return "<!DOCTYPE html>\n" .. (h.emit(
  html { lang="en", 
    head {
      h.meta {charset="utf-8"},
      title { doc.title },
      (styles(doc.styles)),
      h.style{"body{max-width:60em;margin:0 auto;}"}
    },
    body {
      h.header{h.nav{
        role="navigation"},
        map(function(menuitem)
          return h.a{href=menuitem.href, menuitem.title}
        end,doc.menu)
      },
      h.main{doc.contents},
      h.footer{h.p{"Hello footer"}}
    }
  }))
end


function template.post(doc)
  doc.contents = article {
    class="h-card",
    h.header{
      h.h1 {class="p-name", doc.title},
      h.p {
        "Published by ", h.a{class="p-author h-card", doc.author}, 
        -- h5tk doesn't know the <time> element, so it is necessary to use it in string
        ' on <time class="dt-published" datetime="' .. doc.date ..'">'..human_date( doc.time) ..'</time>', 
        "in " , h.a{href="/category-archive.html#" .. doc.category, doc.category}
      },
    },
    h.section{class="abstract p-summary", role="doc-abstract", doc.abstract},
    doc.contents
  }
  return root(doc)
end


function template.index(doc)
  doc.contents = article {
    h.h1{doc.title},
    map(function(v)
      return article {
        h.h1{ h.a {href=v.relative_filepath, v.title }},
        v.abstract
      }
    end, doc.items),
    h.p{h.a{href="archive.html", "Archive"}}
  }
  return root(doc)
end

local function print_archive_items(doc)
  return h.section{
    class="h-feed",
    h.h2{id=doc.name, doc.name, h.a{href=doc.feed, h.img{src="rss.svg", style="width:0.8rem"}}},
    map(function(item)
      return h.div{
        class="h-entry",
        h.p{os.date( "%Y-%m-%d", item.time ), h.a {href=item.relative_filepath, item.title}}
      }
    end, doc.items)
  }
end
        


function template.archive(doc)
  doc.name="Archive"
  doc.feed="feed.rss"
  doc.contents = article {
    h.h1{doc.title},
    h.aside{h.p{h.a{href="category-archive.html", "Category archive"}}},
    print_archive_items(doc)
  }
  return root(doc)
end

function template.categoryarchive(doc)
  -- save category feeds
  for _, c in ipairs(doc.categories) do
    c.feed = c.name .. ".rss"
  end
  doc.contents = article {
    h.h1 {doc.title},
    h.details{
      h.summary {"Table of contents"},
      h.nav{
        map(function(category)
          return h.div {h.a{href="#" .. category.name, category.name}}
        end, doc.categories)
      }
    },
    map(print_archive_items--function(category)
      -- return article {
      --   h.h1 {id=category.name, category.name , h.a{href=category.name.. ".rss", h.img{src="rss.svg", style="width:0.8rem"}}}, 
      --   map(archive_item, category.items)
      -- }
    -- end, 
    ,doc.categories)
  }
  return root(doc)
 
end


return template
