-- endnotes-per-chapter-v2.lua
-- 챕터(H1) 경계마다 그 챕터의 각주를 모아 "주(Notes)" 섹션을 삽입
-- HTML/PDF/DOCX 공통 동작 (DOCX에서도 본문 섹션으로 '주' 생성)

local notes = {}
local chap = 0           -- 현재 챕터 인덱스 (H1 기준)
local TOP = 1            -- 챕터 경계로 보는 헤더 레벨 (보통 H1)

-- 한 챕터의 '주' 블록 생성
local function flush_endnotes_blocks(ch)
  if #notes == 0 then return {} end

  local header = pandoc.Header(2, "주", { class = "endnotes-header", identifier = "endnotes-" .. ch })
  local items = {}

  for i, blocks in ipairs(notes) do
    -- [번호] 라벨(앵커)
    local term = {
      pandoc.Span(
        { pandoc.Str("[" .. tostring(i) .. "]") },
        { id = string.format("fn-%d-%d", ch, i), class = "endnote-label" }
      )
    }

    -- 본문으로 되돌아가기(↩︎)
    local back = pandoc.Para({
      pandoc.Link(
        { pandoc.Str("↩︎") },
        "#" .. string.format("fnref-%d-%d", ch, i),
        "back to reference",
        { class = "endnote-backref" }
      )
    })

    -- 정의부(각주 내용 + back 링크)
    local def_blocks = {}
    for _, b in ipairs(blocks) do table.insert(def_blocks, b) end
    table.insert(def_blocks, back)

    table.insert(items, { term, def_blocks })
  end

  notes = {} -- 비우기
  return { header, pandoc.DefinitionList(items) }
end

-- 각주를 상단첨자 링크(번호)로 대체하고, 내용은 notes 테이블에 모아둔다
function Note(note)
  if chap == 0 then chap = 1 end -- 헤더가 나오기 전에 각주가 있으면 1장으로 본다
  local n = #notes + 1
  notes[n] = note.content

  local ref = pandoc.Link(
    { pandoc.Str(tostring(n)) },
    "#" .. string.format("fn-%d-%d", chap, n),
    "",
    { class = "endnote-ref", id = string.format("fnref-%d-%d", chap, n) }
  )
  return pandoc.Superscript(ref)
end

-- H1을 만나면: 이전 챕터의 '주'를 먼저 삽입하고, 새 챕터로 넘어감
function Header(h)
  if h.level == TOP then
    if chap == 0 then
      chap = 1 -- 첫 H1: 챕터 1 시작(직전 챕터 없음)
      return nil
    else
      -- 다음 챕터 시작 전, 직전 챕터의 '주'를 삽입
      local blocks = flush_endnotes_blocks(chap)
      chap = chap + 1
      if #blocks > 0 then
        local out = {}
        for _, b in ipairs(blocks) do table.insert(out, b) end
        table.insert(out, h)
        return out
      end
    end
  end
  return nil
end

-- 문서 끝에서도 남아있는 각주를 마무리로 삽입
function Pandoc(doc)
  local tail = flush_endnotes_blocks(chap == 0 and 1 or chap)
  if #tail == 0 then return doc end
  local new_blocks = {}
  for _, b in ipairs(doc.blocks) do table.insert(new_blocks, b) end
  for _, b in ipairs(tail) do table.insert(new_blocks, b) end
  return pandoc.Pandoc(new_blocks, doc.meta)
end
