local h5tk = require "h5tk"
local os = require "os"

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
      doc.contents
    }
  }))
end

function template.post(doc)
  -- return "<!DOCTYPE html>\n" .. (h.emit(
  -- html { lang="en", 
  --   head {
  --     h.meta {charset="utf-8"},
  --     title { doc.title },
  --     (styles(doc.styles))
  --   },
  --   body {
      -- article {
      --   h.h1 {doc.title},
      --   h.section{class="abstract", doc.abstract},
      --   doc.contents
      -- }
    -- }
  -- }
  -- ))
  return root {
    title = doc.title,
    styles = doc.styles,
    contents = article {class="h-card",
        h.h1 {class="p-name", doc.title},
        -- h5tk doesn't know date tag
        h.p {"Published by ", h.a{class="p-author h-card", doc.author}, ' on <time class="dt-published" datetime="' .. doc.date ..'">'..os.date("%x", doc.time) ..'</time>'},
        h.section{class="abstract", role="doc-abstract", doc.abstract},
        doc.contents
      }
  }

end

local function archive_item(item)
  return h.p{os.date( "%Y-%m-%d", item.time ), h.a {href=item.relative_filepath, item.title}}
end

function template.index(doc)
  return root {
    title = doc.title,
    styles = doc.styles,
    contents = article {
      h.h1{doc.title},
      map(function(v)
        return article {
          h.h1{ h.a {href=v.relative_filepath, v.title }},
          v.abstract
        }
      end, doc.items)
    }
  }
end

function template.categoryarchive(doc)
  return root {
    title = doc.title,
    styles = doc.styles,
    contents = article {
      h.h1 {doc.title},
      h.details{
        h.summary {"Table of contents"},
        h.nav{
          map(function(category)
            return h.div {h.a{href="#" .. category.name, category.name}}
          end, doc.categories)
        }
      },
      map(function(category)
        return article {
          h.h1 {id=category.name, category.name , h.a{href=category.name.. ".rss", h.img{src="rss.svg", style="width:1em"}}}, 
          map(archive_item, category.items)
        }
      end, doc.categories)
    }
  }
end


return template
