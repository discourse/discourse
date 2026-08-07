# frozen_string_literal: true

describe PrettyText do
  describe "markdown it" do
    it "can properly bake boxes" do
      md = <<~MD
        [],[ ],[x],[X] are all checkboxes
        `[ ]` [x](hello) *[ ]* **[ ]** _[ ]_ __[ ]__ ~~[ ]~~ are not checkboxes
      MD

      cooked = PrettyText.cook(md)

      expect(cooked.scan("chcklst-box").count).to eq(4)
      expect(cooked).to include('<span class="chcklst-box fa fa-square-o" data-chk-off="0">')
      expect(cooked).to include('<span class="chcklst-box fa fa-square-o" data-chk-off="3">')
      expect(cooked).to include(
        '<span class="chcklst-box checked fa fa-square-check-o" data-chk-off="7">',
      )
      expect(cooked).to include('<span class="chcklst-box checked permanent fa fa-square-check">')
      expect(cooked.scan("data-chk-off").count).to eq(3)

      expect(cooked).to include(
        "<code>[ ]</code> <a>x</a> <em>[ ]</em> <strong>[ ]</strong> <em>[ ]</em> <strong>[ ]</strong> <s>[ ]</s> are not checkboxes",
      )
    end

    it "does not treat escaped brackets as checkboxes" do
      md = <<~MD
        \\[x] escaped opening bracket
        [x\\] escaped closing bracket
        \\[x\\] both brackets escaped
        \\[ ] escaped empty checkbox
        [x] real checkbox
      MD

      cooked = PrettyText.cook(md)

      expect(cooked.scan("chcklst-box").count).to eq(1)
      expect(cooked).to include("[x] escaped opening bracket")
      expect(cooked).to include("[x] escaped closing bracket")
      expect(cooked).to include("[x] both brackets escaped")
      expect(cooked).to include("[ ] escaped empty checkbox")
      expect(cooked).to match(
        %r{<span class="chcklst-box checked fa fa-square-check-o" data-chk-off="\d+"></span> real checkbox},
      )
    end

    it "handles escaped checkbox followed by real checkbox" do
      md = <<~MD
        \\[x] hello [x] world
      MD

      cooked = PrettyText.cook(md)

      expect(cooked.scan("chcklst-box").count).to eq(1)
      expect(cooked).to include("[x] hello")
      expect(cooked).to match(
        %r{<span class="chcklst-box checked fa fa-square-check-o" data-chk-off="\d+"></span> world},
      )
    end
  end
end
