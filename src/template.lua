local h5tk = require "h5tk"

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
    table.insert(t, link {rel="stylesheet", type="text/css", href="/css/"..  style})
  end
  return t
end

function root(doc)
  return "<!DOCTYPE html>\n" .. (h.emit(
  html { lang="en", 
    head {
      h.meta {charset="utf-8"},
      title { doc.title },
      (styles(doc.styles))
    },
    body {
      doc.contents
    }
  }))
end

function template.base(doc)
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
    contents = article {
        h.h1 {doc.title},
        h.section{class="abstract", doc.abstract},
        doc.contents
      }
  }

end

function template.index(doc)
  return root {
    title = doc.title,
    styles = doc.styles,
    contents = article {
      function()
        local t = {}
        for k,v in ipairs(doc.items) do
          t[#t+1 ] = article {
            h.h1{ h.a {href=v.relative_filepath, v.title }}

          }
        end
        return t
      end
    }
  }
end

function template.categoryarchive(doc)
  return root {
    title = doc.title,
    styles = doc.styles,
    contents = article {
      map(function(category)
        return article {
          h.h1 {category.name}, 
          h.ul{
            map(function(item)
              return h.li {h.a {href=item.relative_filepath, item.title}}
            end, category.items)
          }
        }
      end, doc.categories)
    }
  }
end


return template
