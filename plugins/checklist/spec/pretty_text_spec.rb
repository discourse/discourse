# frozen_string_literal: true

require "rails_helper"

describe PrettyText do
  describe "markdown it" do
    it "can properly bake boxes" do
      md = <<~MD
        [],[ ],[x],[X] are all checkboxes
        `[ ]` [x](hello) *[ ]* **[ ]** _[ ]_ __[ ]__ ~~[ ]~~ are not checkboxes
      MD

      html = <<~HTML
      <p><span class="chcklst-box fa fa-square-o fa-fw"></span>,<span class="chcklst-box fa fa-square-o fa-fw"></span>,<span class="chcklst-box checked fa fa-check-square-o fa-fw"></span>,<span class="chcklst-box checked permanent fa fa-check-square fa-fw"></span> are all checkboxes<br>
      <code>[ ]</code> <a>x</a> <em>[ ]</em> <strong>[ ]</strong> <em>[ ]</em> <strong>[ ]</strong> <s>[ ]</s> are not checkboxes</p>
      HTML
      cooked = PrettyText.cook(md)
      expect(cooked).to eq(html.strip)
    end
  end
end
