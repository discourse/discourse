# frozen_string_literal: true

describe "Composer - ProseMirror - Code formatting", native_playwright: true do
  include_context "with prosemirror editor"

  let(:composer) { PageObjects::Native::Composer.new(browser_page) }

  def open_composer
    composer.visit
    expect(composer.opened_composer).to be_visible
    composer.editor.click
  end

  describe "code formatting" do
    # formatCode() behavior is determined by selection type and context:
    # 1. Inside code block: convert back to paragraphs (respecting \n\n splits)
    # 2. Empty selection in empty block: create code block
    # 3. Empty selection in non-empty block: toggle stored inline code mark
    # 4. Multi-block selection: create single code block with full content selected
    # 5. Full block selection: create code block with full content selected
    # 6. Partial text selection: toggle inline code marks
    context "when inside code block" do
      it "lets the user indent and outdent selected code with Tab" do
        code = "  first line\n second line\nthird line"
        open_composer
        composer.type_content("```#{code}")

        composer.select_code_block
        composer.editor.press("Tab", timeout: 30_000)
        composer.toggle_rich_editor
        expect(composer.markdown_editor).to have_value(
          "```\n    first line\n   second line\n  third line\n```",
        )

        composer.toggle_rich_editor
        composer.select_code_block
        composer.editor.press("Shift+Tab", timeout: 30_000)
        composer.toggle_rich_editor
        expect(composer.markdown_editor).to have_value("```\n#{code}\n```")
      end

      it "converts code block back to single paragraph" do
        open_composer
        composer.type_content("```\nSingle line of code\n```")
        expect(composer.code_block).to contain_text(/Single line of code/, useInnerText: true)
        composer.editor.press("ArrowUp", timeout: 30_000)
        composer.editor.press("End", timeout: 30_000)
        composer.code_button.click
        expect(composer.paragraph_containing("Single line of code")).to contain_text(
          /Single line of code/,
          useInnerText: true,
        )
        expect(composer.code_block).to have_count(0)
      end

      it "converts code block to multiple paragraphs respecting \\n\\n splits" do
        open_composer
        composer.type_content("First paragraph\n\nSecond paragraph\n\nThird paragraph")
        composer.select_all
        composer.code_button.click
        expect(composer.code_block).to contain_text(
          /First paragraph\n+Second paragraph\n+Third paragraph/,
          useInnerText: true,
        )
        composer.editor.press("ArrowLeft", timeout: 30_000)
        composer.code_button.click
        expect(composer.paragraph_containing("First paragraph")).to contain_text(
          /First paragraph/,
          useInnerText: true,
        )
        expect(composer.paragraph_containing("Second paragraph")).to contain_text(
          /Second paragraph/,
          useInnerText: true,
        )
        expect(composer.paragraph_containing("Third paragraph")).to contain_text(
          /Third paragraph/,
          useInnerText: true,
        )
        expect(composer.code_block).to have_count(0)
      end

      it "selects all resulting paragraphs for easy back-and-forth toggling" do
        open_composer
        composer.type_content("```\nFirst\n\nSecond\n```")
        composer.editor.press("ArrowUp", timeout: 30_000)
        composer.editor.press("End", timeout: 30_000)
        composer.code_button.click
        composer.code_button.click
        expect(composer.code_block).to contain_text(/First\n+Second/, useInnerText: true)
      end
    end

    context "with empty selection (cursor only)" do
      it "creates code block when in empty block" do
        open_composer
        composer.code_button.click
        expect(composer.code_block).to be_visible
        expect(composer.paragraphs).to have_count(1)
      end

      it "toggles stored inline code mark when in non-empty block" do
        open_composer
        composer.type_content("Before ")
        composer.code_button.click
        expect(composer.active_code_button).to be_visible
        composer.type_content("code")
        expect(composer.inline_code).to contain_text(/code/, useInnerText: true)
        composer.code_button.click
        expect(composer.active_code_button).to have_count(0)
        composer.type_content(" after")
        expect(composer.inline_code).to contain_text(/code/, useInnerText: true)
        expect(rich).to contain_text(/Before code after/, useInnerText: true)
      end
    end

    context "with multi-block selection" do
      it "creates single code block from multiple paragraphs" do
        open_composer
        composer.type_content("First paragraph\n\nSecond paragraph")
        composer.select_all
        composer.code_button.click
        expect(composer.code_block).to have_count(1)
        expect(composer.code_block).to contain_text(
          /First paragraph\n+Second paragraph/,
          useInnerText: true,
        )
      end

      it "creates single code block from mixed block types" do
        open_composer
        composer.type_content("# Heading\n\nParagraph text\n\n> Quote text")
        composer.select_all
        composer.code_button.click
        expect(composer.code_block).to have_count(1)
        expect(composer.code_block).to contain_text(
          /Heading\n+Paragraph text\n+Quote text/,
          useInnerText: true,
        )
      end

      it "selects entire content of newly created code block" do
        open_composer
        composer.type_content("First\n\nSecond")
        composer.select_all
        composer.code_button.click
        composer.code_button.click
        expect(composer.paragraph_containing("First")).to contain_text(/First/, useInnerText: true)
        expect(composer.paragraph_containing("Second")).to contain_text(
          /Second/,
          useInnerText: true,
        )
      end

      it "preserves plain text content without markdown conversion" do
        open_composer
        composer.type_content("**Bold text** and *italic text*")
        composer.select_all
        composer.code_button.click
        expect(composer.code_block).to contain_text(/Bold text and italic text/, useInnerText: true)
        expect(
          composer.code_block.filter(hasText: /\*\*Bold text\*\* and \*italic text\*/),
        ).to have_count(0)
      end
    end

    context "with single-block text selection" do
      it "creates inline code marks for partial text selection" do
        open_composer
        composer.type_content("This is a test")
        composer.paragraphs.dblclick
        composer.select_paragraph_text(start_index: 5, end_index: 9)
        composer.code_button.click
        expect(composer.inline_code).to contain_text(/is a/, useInnerText: true)
        expect(rich).to contain_text(/This is a test/, useInnerText: true)
      end

      it "creates inline code marks when selecting all text content within paragraph" do
        open_composer
        composer.type_content("Hello world")
        composer.select_paragraph_text(start_index: 0)
        composer.code_button.click
        expect(composer.inline_code).to contain_text(/Hello world/, useInnerText: true)
      end

      it "removes inline code marks from selection that has them" do
        open_composer
        composer.type_content("This `is a` test")
        composer.select_inline_code
        composer.code_button.click
        expect(composer.inline_code).to have_count(0)
        expect(rich).to contain_text(/This is a test/, useInnerText: true)
      end
    end

    context "with full block selection" do
      it "creates code block from fully selected paragraph" do
        open_composer
        composer.type_content("Full paragraph text")
        composer.select_all
        composer.code_button.click
        expect(composer.code_block).to contain_text(/Full paragraph text/, useInnerText: true)
      end

      it "creates code block from fully selected heading" do
        open_composer
        composer.type_content("# Full heading text")
        composer.select_all
        composer.code_button.click
        expect(composer.code_block).to contain_text(/Full heading text/, useInnerText: true)
      end

      it "creates code block from fully selected list item" do
        open_composer
        composer.type_content("1. List item")
        composer.select_all
        composer.code_button.click
        expect(composer.code_block).to contain_text(/List item/, useInnerText: true)
      end
    end

    context "with round-trip conversion" do
      it "converts multiple paragraphs to code block and back preserving structure" do
        open_composer
        composer.type_content("First paragraph  ")
        composer.editor.press("Shift+Enter", timeout: 30_000)
        composer.type_content("Second line\nSecond paragraph\nThird paragraph")
        expect(composer.paragraphs).to have_count(3)
        expect(composer.paragraph_containing("First paragraph  \nSecond line")).to contain_text(
          /First paragraph  \n+Second line/,
          useInnerText: true,
        )
        expect(composer.paragraph_containing("Second paragraph")).to contain_text(
          /Second paragraph/,
          useInnerText: true,
        )
        expect(composer.paragraph_containing("Third paragraph")).to contain_text(
          /Third paragraph/,
          useInnerText: true,
        )
        composer.select_all
        composer.code_button.click
        expect(composer.code_block).to have_count(1)
        expect(composer.code_block).to contain_text(
          /First paragraph  \n+Second line\n+Second paragraph\n+Third paragraph/,
          useInnerText: true,
        )
        composer.editor.press("ArrowLeft", timeout: 30_000)
        composer.code_button.click
        expect(composer.paragraph_containing("First paragraph  \nSecond line")).to contain_text(
          /First paragraph  \n+Second line/,
          useInnerText: true,
        )
        expect(composer.paragraph_containing("Second paragraph")).to contain_text(
          /Second paragraph/,
          useInnerText: true,
        )
        expect(composer.paragraph_containing("Third paragraph")).to contain_text(
          /Third paragraph/,
          useInnerText: true,
        )
      end
    end
  end

  describe "code marks with fake cursor" do
    it "allows typing after a code mark with/without the mark" do
      open_composer
      composer.type_content("This is ~~SPARTA!~~ `code!`.")
      expect(composer.inline_code).to contain_text(/code!/, useInnerText: true)
      # within the code mark
      composer.editor.press("Backspace", timeout: 30_000)
      composer.editor.press("Backspace", timeout: 30_000)
      composer.type_content("!")
      expect(composer.inline_code).to contain_text(/code!/, useInnerText: true)
      # after the code mark
      composer.editor.press("ArrowRight", timeout: 30_000)
      composer.type_content(".")
      composer.toggle_rich_editor
      expect(composer.markdown_editor).to have_value("This is ~~SPARTA!~~ `code!`.")
    end

    it "allows typing before a code mark with/without the mark" do
      open_composer
      composer.type_content("`code mark`")
      expect(composer.inline_code).to contain_text(/code mark/, useInnerText: true)
      # before the code mark
      composer.editor.press(
        RUBY_PLATFORM.match?(/darwin/i) ? "Meta+ArrowLeft" : "Home",
        timeout: 30_000,
      )
      browser_page.wait_for_timeout(100)
      composer.editor.press("ArrowLeft", timeout: 30_000)
      composer.type_content("..")
      # within the code mark
      composer.editor.press("ArrowRight", timeout: 30_000)
      composer.type_content("!!")
      composer.toggle_rich_editor
      expect(composer.markdown_editor).to have_value("..`!!code mark`")
    end
  end
end
