# frozen_string_literal: true

RSpec.describe Checklist::CheckboxLocator do
  describe ".call" do
    subject(:checkboxes) { described_class.call(raw:) }

    before { SiteSetting.checklist_enabled = true }

    def located
      checkboxes.map do |checkbox|
        checkbox.permanent? ? :permanent : [checkbox.offset, checkbox.segment]
      end
    end

    context "when a stored cooked with offsets is provided" do
      subject(:checkboxes) { described_class.call(raw:, cooked:) }

      let(:raw) { "- [ ] first\n- [x] second" }
      let(:cooked) { PrettyText.cook(raw) }

      it "locates from the stored cooked without recooking" do
        cooked
        PrettyText.expects(:cook).never

        expect(located).to eq([[2, "[ ]"], [14, "[x]"]])
      end
    end

    context "when the stored cooked predates the offset attribute" do
      subject(:checkboxes) { described_class.call(raw:, cooked:) }

      let(:raw) { "- [ ] first\n- [x] second" }
      let(:cooked) { PrettyText.cook(raw).gsub(%r{ data-chk-off="\d+"}, "") }

      it "falls back to a fresh cook and locates every checkbox" do
        expect(located).to eq([[2, "[ ]"], [14, "[x]"]])
      end
    end

    context "when the stored cooked is stale" do
      subject(:checkboxes) { described_class.call(raw:, cooked:) }

      let(:raw) { "🎉 party\n\n[ ] task" }
      let(:cooked) { PrettyText.cook("- [ ] something\n- [x] entirely different") }

      it "falls back to a fresh cook of the current raw" do
        expect(located).to eq([[9, "[ ]"]])
      end
    end

    context "when checkboxes are in a list" do
      let(:raw) { "- [ ] first\n- [x] second" }

      it "locates them all at their raw offsets" do
        expect(located).to eq([[2, "[ ]"], [14, "[x]"]])
      end
    end

    context "when checkboxes follow a paragraph" do
      let(:raw) { "hello\n\n[ ] a [x] b" }

      it "locates every checkbox on the line" do
        expect(located).to eq([[7, "[ ]"], [13, "[x]"]])
      end
    end

    context "when a checkbox is inside a strikethrough" do
      let(:raw) { "~~[x] done~~ [ ] redo" }

      it "only locates the checkbox the renderer draws" do
        expect(located).to eq([[13, "[ ]"]])
      end
    end

    context "when a checkbox is inside an emphasis" do
      let(:raw) { "*[x]* [ ] real" }

      it "only locates the checkbox the renderer draws" do
        expect(located).to eq([[6, "[ ]"]])
      end
    end

    context "when a checkbox label sits inside a markdown link" do
      let(:raw) { "[x](https://example.com) [ ] real" }

      it "locates only the real checkbox, never the link label" do
        expect(located).to eq([[25, "[ ]"]])
      end
    end

    context "when the raw contains multibyte characters" do
      let(:raw) { "🎉 party\n\n[ ] task" }

      it "locates the checkbox at its character offset" do
        expect(located).to eq([[9, "[ ]"]])
      end

      it "replaces the right characters" do
        expect(checkboxes.first.replace_in(raw, checked: true)).to eq("🎉 party\n\n[x] task")
      end
    end

    context "when a checkbox is in a table cell" do
      let(:raw) { "| a | b |\n|---|---|\n| [x] no | [ ] go |" }

      it "locates both cell checkboxes" do
        expect(located).to eq([[22, "[x]"], [31, "[ ]"]])
      end
    end

    context "when an escaped checkbox precedes a real one" do
      let(:raw) { "\\[x] escaped [x] real" }

      it "only locates the real checkbox" do
        expect(located).to eq([[13, "[x]"]])
      end
    end

    context "when the checkbox follows a double backslash" do
      let(:raw) { "\\\\[x] boom [ ] real" }

      it "locates the box the renderer draws after the literal backslash" do
        expect(located).to eq([[2, "[x]"], [11, "[ ]"]])
      end
    end

    context "when the raw starts with an image markdown" do
      let(:raw) { "![](upload://z.jpg)\n[] first\n[] second" }

      it "skips the image brackets and locates both legacy checkboxes" do
        expect(located).to eq([[20, "[]"], [29, "[]"]])
      end

      it "checks the first legacy checkbox" do
        expect(checkboxes.first.replace_in(raw, checked: true)).to eq(
          "![](upload://z.jpg)\n[x] first\n[] second",
        )
      end
    end

    context "when a checkbox is inside a fenced code block" do
      let(:raw) { "[ ] before\n```\n[ ] inside\n```\n[ ] after" }

      it "only locates the checkboxes outside the block" do
        expect(located).to eq([[0, "[ ]"], [30, "[ ]"]])
      end
    end

    context "when a checkbox is inside inline code" do
      let(:raw) { "[ ] real `[ ]` code [ ] real" }

      it "only locates the checkboxes outside the code" do
        expect(located).to eq([[0, "[ ]"], [20, "[ ]"]])
      end
    end

    context "when a checkbox uses the permanent marker" do
      let(:raw) { "[X] permanent\n[x] not permanent" }

      it "flags the permanent one and locates the toggleable one" do
        expect(located).to eq([:permanent, [14, "[x]"]])
      end

      it "marks only the uppercase one as permanent" do
        expect(checkboxes.map(&:permanent?)).to eq([true, false])
      end
    end

    context "when the raw uses CRLF line endings" do
      let(:raw) { "[ ] alpha\r\n\r\n[ ] beta" }

      it "locates both checkboxes at their raw offsets" do
        expect(located).to eq([[0, "[ ]"], [13, "[ ]"]])
      end
    end

    context "when checkboxes appear after many skipped blocks" do
      let(:raw) { <<~RAW }
        `[x]`
        *[x]*
        **[x]**
        _[x]_
        __[x]__
        ~~[x]~~

        [code]
        [x]
        [ ]
        [ ]
        [x]
        [/code]

        ```
        [x]
        [ ]
        [ ]
        [x]
        ```

        Actual checkboxes:
        [] first
        [x] second
        * test[x]*third*
        [x] fourth
        [x] fifth
      RAW

      it "only locates the five real checkboxes" do
        expect(located).to eq([[119, "[]"], [128, "[x]"], [145, "[x]"], [156, "[x]"], [167, "[x]"]])
      end

      it "unchecks the fourth real checkbox" do
        new_raw = checkboxes[3].replace_in(raw, checked: false)

        expect(new_raw).to include("[ ] fourth")
        expect(new_raw).to include("[x] second")
        expect(new_raw).to include("[x] fifth")
      end
    end

    context "when the raw contains date-range bbcode" do
      let(:raw) { <<~RAW }
        [date-range from=2024-03-22 to=2024-03-23]

        [ ] task 1
        [ ] task 2
        [x] task 3
      RAW

      it "only locates the three checkboxes" do
        expect(located).to eq([[44, "[ ]"], [55, "[ ]"], [66, "[x]"]])
      end
    end

    context "when checkboxes are in an unordered list" do
      let(:raw) { "* [x] checked\n* [] test\n* [] two" }

      it "locates all three checkboxes" do
        expect(located).to eq([[2, "[x]"], [16, "[]"], [26, "[]"]])
      end
    end

    context "when brackets are escaped in different ways" do
      let(:raw) do
        "\\[x] escaped opening\n[x\\] escaped closing\n\\[x\\] both escaped\n[ ] real checkbox\n[x] another real one"
      end

      it "only locates the two real checkboxes" do
        expect(located).to eq([[61, "[ ]"], [79, "[x]"]])
      end
    end

    context "when the post has no checkboxes" do
      let(:raw) { "just some text without any boxes" }

      it "locates nothing" do
        expect(checkboxes).to be_empty
      end
    end
  end
end
