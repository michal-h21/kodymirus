local h5tk = require "h5tk"
local template = {}

local h = h5tk.init(true)
local html, head, body, title, link, article = h.html, h.head, h.body, h.title, h.link, h.article

local function styles(s)
  local t = {}
  for _, style in ipairs(s) do
    table.insert(t, link {rel="stylesheet", type="text/css", href="/css/"..  style})
  end
  return t
end

function template.base(doc)
  return "<!DOCTYPE html>\n" .. (h.emit(
  html { lang="en", 
    head {
      h.meta {charset="utf-8"},
      title { doc.title },
      (styles(doc.styles))
    },
    body {
      article {
        h.h1 {doc.title},
        h.section{class="abstract", doc.abstract},
        doc.contents
      }
    }
  }
  ))

end

return template
