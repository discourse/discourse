# frozen_string_literal: true

RSpec.describe Checklist::CheckboxLocator do
  before { SiteSetting.checklist_enabled = true }

  def locate(raw, index, cooked: PrettyText.cook(raw))
    post = Post.new(raw:, cooked:, topic_id: 1)
    described_class.call(post:, index:)
  end

  describe ".call" do
    it "uses source hints from stored cooked without recooking" do
      raw = "- [ ] first\n- [x] second"
      cooked = PrettyText.cook(raw)
      Post.any_instance.expects(:cook).never

      first = locate(raw, 0, cooked:)
      second = locate(raw, 1, cooked:)

      expect([first.count, first.checkbox.offset, first.checkbox.segment]).to eq([2, 2, "[ ]"])
      expect([second.count, second.checkbox.offset, second.checkbox.segment]).to eq([2, 14, "[x]"])
    end

    it "performs one fallback cook for legacy stored HTML" do
      raw = "- [ ] first\n- [x] second"
      cooked = PrettyText.cook(raw)
      legacy_cooked = cooked.gsub(%r{ data-chk-src="[^"]+"}, "")
      Post.any_instance.expects(:cook).once.with(raw).returns(cooked)

      location = locate(raw, 1, cooked: legacy_cooked)

      expect(location.checkbox.replace_in(raw, checked: false)).to eq("- [ ] first\n- [ ] second")
    end

    it "ignores marker-shaped text that Markdown does not render as controls" do
      raw = <<~MARKDOWN
        `[x]`
        *[x]*
        ~~[x]~~
        [x](https://example.com)
        [code][x][/code]
        ```
        [x]
        ```
        [ ] first
        [x] second
      MARKDOWN

      first = locate(raw, 0)
      second = locate(raw, 1)

      expect([first.count, first.checkbox.segment]).to eq([2, "[ ]"])
      expect(first.checkbox.replace_in(raw, checked: true)).to end_with("[x] first\n[x] second\n")
      expect(second.checkbox.replace_in(raw, checked: false)).to end_with("[ ] first\n[ ] second\n")
    end

    it "maps past checkbox-shaped image and link metadata" do
      raw = <<~MARKDOWN
        ![](<https://example.test/[x]>)[x]
        [link](<https://example.test/[x]> "[x]") [ ] visible
      MARKDOWN

      image_line = locate(raw, 0)
      link_line = locate(raw, 1)

      expect(image_line.checkbox.replace_in(raw, checked: false)).to start_with(
        "![](<https://example.test/[x]>)[ ]",
      )
      expect(link_line.checkbox.replace_in(raw, checked: true)).to end_with(
        '[link](<https://example.test/[x]> "[x]") [x] visible' + "\n",
      )
    end

    it "maps checkboxes in blockquotes, lists, and table cells" do
      raw = <<~MARKDOWN
        > - [ ] quoted

        | a | b |
        |---|---|
        | [x] no | [ ] go |
      MARKDOWN

      quoted = locate(raw, 0)
      first_cell = locate(raw, 1)
      second_cell = locate(raw, 2)

      expect(quoted.checkbox.replace_in(raw, checked: true)).to include("> - [x] quoted")
      expect(first_cell.checkbox.replace_in(raw, checked: false)).to include("| [ ] no | [ ] go |")
      expect(second_cell.checkbox.replace_in(raw, checked: true)).to include("| [x] no | [x] go |")
    end

    it "handles date-range BBCode before checkboxes" do
      raw = <<~MARKDOWN
        [date-range from=2024-03-22 to=2024-03-23]

        [ ] task 1
        [x] task 2
      MARKDOWN

      expect(locate(raw, 0).checkbox.replace_in(raw, checked: true)).to include("[x] task 1")
      expect(locate(raw, 1).checkbox.replace_in(raw, checked: false)).to include("[ ] task 2")
    end

    it "handles escaped markers, Unicode, legacy markers, and CRLF" do
      raw = "🎉 \\[x] escaped\r\n[] first\r\n[x] second"

      first = locate(raw, 0)
      second = locate(raw, 1)

      expect(first.checkbox.replace_in(raw, checked: true)).to eq(
        "🎉 \\[x] escaped\r\n[x] first\r\n[x] second",
      )
      expect(second.checkbox.replace_in(raw, checked: false)).to eq(
        "🎉 \\[x] escaped\r\n[] first\r\n[ ] second",
      )
    end

    it "identifies permanent checkboxes without a mutable source hint" do
      raw = "[X] permanent\n[x] regular"

      permanent = locate(raw, 0)
      regular = locate(raw, 1)

      expect([permanent.count, permanent.checkbox.permanent?]).to eq([2, true])
      expect([regular.count, regular.checkbox.toggleable?]).to eq([2, true])
    end

    it "returns the rendered count without a checkbox for an invalid index" do
      location = locate("[ ] only", 2)

      expect(location.count).to eq(1)
      expect(location.checkbox).to be_nil
    end

    it "fails closed when a contextual cook cannot produce source hints" do
      raw = "[ ] only"
      hintless_cooked = PrettyText.cook(raw).gsub(%r{ data-chk-src="[^"]+"}, "")
      Post.any_instance.expects(:cook).once.with(raw).returns(hintless_cooked)

      location = locate(raw, 0, cooked: hintless_cooked)

      expect([location.count, location.checkbox]).to eq([1, nil])
    end

    it "fails closed when a source hint does not agree with raw" do
      raw = "[ ] first\n[ ] second"
      fresh_cooked = PrettyText.cook(raw)
      cooked = fresh_cooked.sub('data-chk-src="0:0"', 'data-chk-src="1:0"')
      Post.any_instance.expects(:cook).once.with(raw).returns(fresh_cooked)

      location = locate(raw, 0, cooked:)

      expect(location.checkbox.offset).to eq(0)
    end
  end
end
