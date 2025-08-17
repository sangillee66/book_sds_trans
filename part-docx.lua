-- part-docx.lua
-- DOCX에서 파트를 Heading 1로, 장을 Heading 2로 만들어 TOC 단계가 분명해지도록 함.
-- 전제: 파트 파일의 YAML에 part: true 가 있음.

local is_docx = FORMAT:match('docx') ~= nil
local is_part = false
local title_text = nil

local function pagebreak_docx()
  return pandoc.RawBlock('openxml','<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
end

function Meta(m)
  -- 파트 파일 판정 (part: true)
  if m.part and m.part == true then
    is_part = true
  end
  -- 문서 제목 확보
  if m.title then
    title_text = pandoc.utils.stringify(m.title)
  end
end

-- 파트 파일: 페이지 나눔 + Heading 1 제목 삽입
function Pandoc(doc)
  if not is_docx then return doc end

  if is_part then
    local new = {}
    -- (원하면 첫 파트에서만 페이지 나눔을 빼도 됨)
    table.insert(new, pagebreak_docx())
    if title_text and title_text ~= '' then
      table.insert(new, pandoc.Header(1, title_text, pandoc.Attr('', {'unnumbered','part'})))
    end
    for i = 1, #doc.blocks do
      new[#new+1] = doc.blocks[i]
    end
    doc.blocks = new
    return doc
  else
    -- 일반 장 파일: 최상위 Heading(보통 1)을 2로 모두 강등
    for i, b in ipairs(doc.blocks) do
      if b.t == 'Header' and b.level == 1 then
        b.level = 2
        doc.blocks[i] = b
      end
    end
    return doc
  end
end
