# frozen_string_literal: true

describe PrettyText do
  describe "markdown it" do
    it "can properly bake boxes" do
      md = <<~MD
        [],[ ],[x],[X] are all checkboxes
        `[ ]` [x](hello) *[ ]* **[ ]** _[ ]_ __[ ]__ ~~[ ]~~ are not checkboxes
      MD

      html = <<~HTML
      <p><span class="chcklst-box fa fa-square-o"></span>,<span class="chcklst-box fa fa-square-o"></span>,<span class="chcklst-box checked fa fa-square-check-o"></span>,<span class="chcklst-box checked permanent fa fa-square-check"></span> are all checkboxes<br>
      <code>[ ]</code> <a>x</a> <em>[ ]</em> <strong>[ ]</strong> <em>[ ]</em> <strong>[ ]</strong> <s>[ ]</s> are not checkboxes</p>
      HTML
      cooked = PrettyText.cook(md)
      expect(cooked).to eq(html.strip)
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
      expect(cooked).to include(
        '<span class="chcklst-box checked fa fa-square-check-o"></span> real checkbox',
      )
    end

    it "handles escaped checkbox followed by real checkbox" do
      md = <<~MD
        \\[x] hello [x] world
      MD

      cooked = PrettyText.cook(md)

      expect(cooked.scan("chcklst-box").count).to eq(1)
      expect(cooked).to include("[x] hello")
      expect(cooked).to include(
        '<span class="chcklst-box checked fa fa-square-check-o"></span> world',
      )
    end
  end
end
