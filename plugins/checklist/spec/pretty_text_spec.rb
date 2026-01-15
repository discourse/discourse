# frozen_string_literal: true

RSpec.describe PrettyText do
  describe "checklist" do
    it "renders checkboxes with correct classes and offsets" do
      cooked = PrettyText.cook("[ ] unchecked [x] checked [X] permanent")

      expect(cooked.scan("chcklst-box").count).to eq(3)
      expect(cooked).to include("fa-square-o")
      expect(cooked).to include("checked fa fa-square-check-o")
      expect(cooked).to include("checked permanent fa fa-square-check")
      expect(cooked).to include('data-chk-off="0"', 'data-chk-off="14"')
      expect(cooked.scan("data-chk-off").count).to eq(2) # permanent checkbox has no offset
    end

    it "handles checkboxes in lists" do
      cooked = PrettyText.cook("- [ ] first\n- [x] second")

      expect(cooked.scan("chcklst-box").count).to eq(2)
      expect(cooked).to include('data-chk-off="2"', 'data-chk-off="14"')
    end

    it "does not render non-checkbox patterns" do
      patterns = [
        "[] empty brackets",
        "*[x]* in emphasis",
        "**[x]** in bold",
        "_[x]_ in underscore emphasis",
        "~~[x]~~ in strikethrough",
        "[x](http://example.com) link",
        "![x](image.png) image alt",
        "\\[x] escaped",
      ]

      patterns.each do |pattern|
        cooked = PrettyText.cook(pattern)
        expect(cooked).not_to include("chcklst-box"), "Expected no checkbox in: #{pattern}"
      end
    end

    it "skips checkboxes inside code blocks" do
      cooked = PrettyText.cook("[ ] before\n```\n[ ] inside\n```\n[ ] after")

      expect(cooked.scan("chcklst-box").count).to eq(2)
      expect(cooked).to include("[ ] inside\n</code>")
    end

    it "skips checkboxes inside inline code" do
      cooked = PrettyText.cook("[ ] real `[ ]` code [ ] real")

      expect(cooked.scan("chcklst-box").count).to eq(2)
      expect(cooked).to include("[ ]</code>")
    end

    it "handles escaped checkbox followed by real checkbox" do
      cooked = PrettyText.cook("\\[x] escaped [x] real")

      expect(cooked.scan("chcklst-box").count).to eq(1)
      expect(cooked).to include("[x] escaped")
    end
  end
end
