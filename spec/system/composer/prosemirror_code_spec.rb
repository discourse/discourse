# frozen_string_literal: true

describe "Composer - ProseMirror - Code formatting", type: :system do
  include_context "with prosemirror editor"

  describe "code formatting" do
    # formatCode() behavior is determined by selection type and context:
    # 1. Inside code block: convert back to paragraphs (respecting \n\n splits)
    # 2. Empty selection in empty block: create code block
    # 3. Empty selection in non-empty block: toggle stored inline code mark
    # 4. Multi-block selection: create single code block with full content selected
    # 5. Full block selection: create code block with full content selected
    # 6. Partial text selection: toggle inline code marks
    context "when inside code block" do
      it "converts code block back to single paragraph" do
        open_composer
        composer.type_content("```\nSingle line of code\n```")
        expect(rich).to have_css("pre code", text: "Single line of code")
        composer.send_keys(:up, :end)
        find(".toolbar__button.code").click
        expect(rich).to have_css("p", text: "Single line of code")
        expect(rich).to have_no_css("pre code")
      end

      it "converts code block to multiple paragraphs respecting \\n\\n splits" do
        open_composer
        composer.type_content("First paragraph\n\nSecond paragraph\n\nThird paragraph")
        composer.select_all
        find(".toolbar__button.code").click
        expect(rich).to have_css(
          "pre code",
          text: "First paragraph\nSecond paragraph\nThird paragraph",
        )
        composer.send_keys(:left)
        find(".toolbar__button.code").click
        expect(rich).to have_css("p", text: "First paragraph")
        expect(rich).to have_css("p", text: "Second paragraph")
        expect(rich).to have_css("p", text: "Third paragraph")
        expect(rich).to have_no_css("pre code")
      end

      it "selects all resulting paragraphs for easy back-and-forth toggling" do
        open_composer
        composer.type_content("```\nFirst\n\nSecond\n```")
        composer.send_keys(:up, :end)
        find(".toolbar__button.code").click
        find(".toolbar__button.code").click
        expect(rich).to have_css("pre code", text: "First\nSecond")
      end
    end

    context "with empty selection (cursor only)" do
      it "creates code block when in empty block" do
        open_composer
        find(".toolbar__button.code").click
        expect(rich).to have_css("pre code")
        expect(rich).to have_css("p", count: 1)
      end

      it "toggles stored inline code mark when in non-empty block" do
        open_composer
        composer.type_content("Before ")
        find(".toolbar__button.code").click
        expect(page).to have_css(".toolbar__button.code.--active")
        composer.type_content("code")
        expect(rich).to have_css("code", text: "code")
        find(".toolbar__button.code").click
        expect(page).to have_no_css(".toolbar__button.code.--active")
        composer.type_content(" after")
        expect(rich).to have_css("code", text: "code")
        expect(rich).to have_content("Before code after")
      end
    end

    context "with multi-block selection" do
      it "creates single code block from multiple paragraphs" do
        open_composer
        composer.type_content("First paragraph\n\nSecond paragraph")
        composer.select_all
        find(".toolbar__button.code").click
        expect(rich).to have_css("pre code", count: 1)
        expect(rich).to have_css("pre code", text: "First paragraph\nSecond paragraph")
      end

      it "creates single code block from mixed block types" do
        open_composer
        composer.type_content("# Heading\n\nParagraph text\n\n> Quote text")
        composer.select_all
        find(".toolbar__button.code").click
        expect(rich).to have_css("pre code", count: 1)
        expect(rich).to have_css("pre code", text: "Heading\nParagraph text\nQuote text")
      end

      it "selects entire content of newly created code block" do
        open_composer
        composer.type_content("First\n\nSecond")
        composer.select_all
        find(".toolbar__button.code").click
        find(".toolbar__button.code").click
        expect(rich).to have_css("p", text: "First")
        expect(rich).to have_css("p", text: "Second")
      end

      it "preserves plain text content without markdown conversion" do
        open_composer
        composer.type_content("**Bold text** and *italic text*")
        composer.select_all
        find(".toolbar__button.code").click
        expect(rich).to have_css("pre code", text: "Bold text and italic text")
        expect(rich).to have_no_css("pre code", text: "**Bold text** and *italic text*")
      end
    end

    context "with single-block text selection" do
      it "creates inline code marks for partial text selection" do
        open_composer
        composer.type_content("This is a test")
        rich.find("p").double_click
        page.execute_script(<<~JS)
          const selection = window.getSelection();
          const range = document.createRange();
          const textNode = document.querySelector('.ProseMirror p').firstChild;
          range.setStart(textNode, 5);
          range.setEnd(textNode, 9);
          selection.removeAllRanges();
          selection.addRange(range);
        JS
        find(".toolbar__button.code").click
        expect(rich).to have_css("code", text: "is a")
        expect(rich).to have_content("This is a test")
      end

      it "creates inline code marks when selecting all text content within paragraph" do
        open_composer
        composer.type_content("Hello world")
        page.execute_script(<<~JS)
          const selection = window.getSelection();
          const range = document.createRange();
          const textNode = document.querySelector('.ProseMirror p').firstChild;
          range.setStart(textNode, 0);
          range.setEnd(textNode, textNode.textContent.length);
          selection.removeAllRanges();
          selection.addRange(range);
        JS
        find(".toolbar__button.code").click
        expect(rich).to have_css("code", text: "Hello world")
      end

      it "removes inline code marks from selection that has them" do
        open_composer
        composer.type_content("This `is a` test")
        page.execute_script(<<~JS)
          const selection = window.getSelection();
          const range = document.createRange();
          const codeElement = document.querySelector('.ProseMirror code');
          range.selectNodeContents(codeElement);
          selection.removeAllRanges();
          selection.addRange(range);
        JS
        find(".toolbar__button.code").click
        expect(rich).to have_no_css("code")
        expect(rich).to have_content("This is a test")
      end
    end

    context "with full block selection" do
      it "creates code block from fully selected paragraph" do
        open_composer
        composer.type_content("Full paragraph text")
        composer.select_all
        find(".toolbar__button.code").click
        expect(rich).to have_css("pre code", text: "Full paragraph text")
      end

      it "creates code block from fully selected heading" do
        open_composer
        composer.type_content("# Full heading text")
        composer.select_all
        find(".toolbar__button.code").click
        expect(rich).to have_css("pre code", text: "Full heading text")
      end

      it "creates code block from fully selected list item" do
        open_composer
        composer.type_content("1. List item")
        composer.select_all
        find(".toolbar__button.code").click
        expect(rich).to have_css("pre code", text: "List item")
      end
    end

    context "with round-trip conversion" do
      it "converts multiple paragraphs to code block and back preserving structure" do
        open_composer
        composer.type_content("First paragraph  ")
        composer.send_keys(:shift, :enter)
        composer.type_content("Second line\nSecond paragraph\nThird paragraph")
        expect(rich).to have_css("p", count: 3)
        expect(rich).to have_css("p", text: "First paragraph  \nSecond line")
        expect(rich).to have_css("p", text: "Second paragraph")
        expect(rich).to have_css("p", text: "Third paragraph")
        composer.select_all
        find(".toolbar__button.code").click
        expect(rich).to have_css("pre code", count: 1)
        expect(rich).to have_css(
          "pre code",
          text: "First paragraph  \nSecond line\nSecond paragraph\nThird paragraph",
        )
        composer.send_keys(:left)
        find(".toolbar__button.code").click
        expect(rich).to have_css("p", text: "First paragraph  \nSecond line")
        expect(rich).to have_css("p", text: "Second paragraph")
        expect(rich).to have_css("p", text: "Third paragraph")
      end
    end
  end

  describe "code marks with fake cursor" do
    it "allows typing after a code mark with/without the mark" do
      open_composer
      composer.type_content("This is ~~SPARTA!~~ `code!`.")
      expect(rich).to have_css("code", text: "code!")
      # within the code mark
      composer.send_keys(:backspace)
      composer.send_keys(:backspace)
      composer.type_content("!")
      expect(rich).to have_css("code", text: "code!")
      # after the code mark
      composer.send_keys(:right)
      composer.type_content(".")
      composer.toggle_rich_editor
      expect(composer).to have_value("This is ~~SPARTA!~~ `code!`.")
    end

    xit "allows typing before a code mark with/without the mark" do
      open_composer
      composer.type_content("`code mark`")
      expect(rich).to have_css("code", text: "code mark")
      # before the code mark
      composer.send_keys(:home)
      composer.send_keys(:left)
      composer.type_content("..")
      # within the code mark
      composer.send_keys(:right)
      composer.type_content("!!")
      composer.toggle_rich_editor
      expect(composer).to have_value("..`!!code mark`")
    end
  end
end
