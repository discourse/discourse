# frozen_string_literal: true

describe "Composer - ProseMirror - Code formatting" do
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
      it "lets the user indent and outdent selected code with Tab" do
        code = "  first line\n second line\nthird line"
        open_composer
        composer.type_content("```#{code}")

        composer.select_code_block
        composer.send_keys(:tab)
        composer.toggle_rich_editor
        expect(composer).to have_value("```\n    first line\n   second line\n  third line\n```")

        composer.toggle_rich_editor
        composer.select_code_block
        composer.send_keys(%i[shift tab])
        composer.toggle_rich_editor
        expect(composer).to have_value("```\n#{code}\n```")
      end

      it "lets the user convert independent code blocks", aggregate_failures: true do
        open_composer

        aggregate_failures("converts code block back to single paragraph") do
          composer.type_content("```\nSingle line of code\n```")
          expect(rich).to have_css("pre code", text: "Single line of code")
          composer.send_keys(:up, :end)
          find(".toolbar__button.code").click
          expect(rich).to have_css("p", text: "Single line of code")
          expect(rich).to have_no_css("pre code")
        end

        reset_composer

        aggregate_failures("converts code block to multiple paragraphs respecting \\n\\n splits") do
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

        reset_composer

        aggregate_failures("selects all resulting paragraphs for easy back-and-forth toggling") do
          composer.type_content("```\nFirst\n\nSecond\n```")
          composer.send_keys(:up, :end)
          find(".toolbar__button.code").click
          find(".toolbar__button.code").click
          expect(rich).to have_css("pre code", text: "First\nSecond")
        end
      end
    end

    context "with empty selection (cursor only)" do
      it "lets the user format independent cursor positions", aggregate_failures: true do
        open_composer

        aggregate_failures("creates code block when in empty block") do
          find(".toolbar__button.code").click
          expect(rich).to have_css("pre code")
          expect(rich).to have_css("p", count: 1)
        end

        reset_composer

        aggregate_failures("toggles stored inline code mark when in non-empty block") do
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
    end

    context "with multi-block selection" do
      it "lets the user convert independent selections of multiple blocks",
         aggregate_failures: true do
        open_composer

        aggregate_failures("creates single code block from multiple paragraphs") do
          composer.type_content("First paragraph\n\nSecond paragraph")
          composer.select_all
          find(".toolbar__button.code").click
          expect(rich).to have_css("pre code", count: 1)
          expect(rich).to have_css("pre code", text: "First paragraph\nSecond paragraph")
        end

        reset_composer

        aggregate_failures("creates single code block from mixed block types") do
          composer.type_content("# Heading\n\nParagraph text\n\n> Quote text")
          composer.select_all
          find(".toolbar__button.code").click
          expect(rich).to have_css("pre code", count: 1)
          expect(rich).to have_css("pre code", text: "Heading\nParagraph text\nQuote text")
        end

        reset_composer

        aggregate_failures("selects entire content of newly created code block") do
          composer.type_content("First\n\nSecond")
          composer.select_all
          find(".toolbar__button.code").click
          find(".toolbar__button.code").click
          expect(rich).to have_css("p", text: "First")
          expect(rich).to have_css("p", text: "Second")
        end

        reset_composer

        aggregate_failures("preserves plain text content without markdown conversion") do
          composer.type_content("**Bold text** and *italic text*")
          composer.select_all
          find(".toolbar__button.code").click
          expect(rich).to have_css("pre code", text: "Bold text and italic text")
          expect(rich).to have_no_css("pre code", text: "**Bold text** and *italic text*")
        end
      end
    end

    context "with single-block text selection" do
      it "lets the user format independent text selections", aggregate_failures: true do
        open_composer

        aggregate_failures("creates inline code marks for partial text selection") do
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

        reset_composer

        aggregate_failures(
          "creates inline code marks when selecting all text content within paragraph",
        ) do
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

        reset_composer

        aggregate_failures("removes inline code marks from selection that has them") do
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
    end

    context "with full block selection" do
      it "lets the user convert independent whole blocks", aggregate_failures: true do
        open_composer

        aggregate_failures("creates code block from fully selected paragraph") do
          composer.type_content("Full paragraph text")
          composer.select_all
          find(".toolbar__button.code").click
          expect(rich).to have_css("pre code", text: "Full paragraph text")
        end

        reset_composer

        aggregate_failures("creates code block from fully selected heading") do
          composer.type_content("# Full heading text")
          composer.select_all
          find(".toolbar__button.code").click
          expect(rich).to have_css("pre code", text: "Full heading text")
        end

        reset_composer

        aggregate_failures("creates code block from fully selected list item") do
          composer.type_content("1. List item")
          composer.select_all
          find(".toolbar__button.code").click
          expect(rich).to have_css("pre code", text: "List item")
        end
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
    it "lets the user type around independent code marks", aggregate_failures: true do
      open_composer

      aggregate_failures("allows typing after a code mark with/without the mark") do
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

      reset_composer

      aggregate_failures("allows typing before a code mark with/without the mark") do
        composer.type_content("`code mark`")
        expect(rich).to have_css("code", text: "code mark")
        # before the code mark
        composer.send_keys(SystemHelpers::LINE_START_KEY)
        wait_for_timeout
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
end
