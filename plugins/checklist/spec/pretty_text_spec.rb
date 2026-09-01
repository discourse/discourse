# frozen_string_literal: true

RSpec.describe PrettyText do
  before { SiteSetting.checklist_enabled = true }

  def checklist_nodes(raw)
    Nokogiri::HTML5.fragment(PrettyText.cook(raw)).css("span.chcklst-box")
  end

  describe "checklist Markdown" do
    it "renders mutable and permanent checkbox variants" do
      raw = "[],[ ],[x],[X] are all checkboxes"
      nodes = checklist_nodes(raw)

      expect(nodes.map { |node| node["data-chk-src"] }).to eq(["0:0", "0:1", "0:2", nil])
      expect(nodes.map { |node| node.classes.include?("checked") }).to eq(
        [false, false, true, true],
      )
      expect(nodes.last.classes).to include("permanent")
    end

    it "does not render markers in code, links, emphasis, or strikethrough" do
      raw = "`[ ]` [x](hello) *[ ]* **[ ]** _[ ]_ __[ ]__ ~~[ ]~~ [ ] real"
      nodes = checklist_nodes(raw)

      expect(nodes.size).to eq(1)
      expect(nodes.first["data-chk-src"]).to eq("0:7")
    end

    it "does not treat escaped brackets as checkboxes" do
      raw = <<~MARKDOWN
        \\[x] escaped opening bracket
        [x\\] escaped closing bracket
        \\[x\\] both brackets escaped
        \\[ ] escaped empty checkbox
        [x] real checkbox
      MARKDOWN
      cooked = PrettyText.cook(raw)
      nodes = Nokogiri::HTML5.fragment(cooked).css("span.chcklst-box")

      expect(nodes.size).to eq(1)
      expect(nodes.first["data-chk-src"]).to eq("4:0")
      expect(cooked).to include("[x] escaped opening bracket")
      expect(cooked).to include("[x] escaped closing bracket")
      expect(cooked).to include("[x] both brackets escaped")
      expect(cooked).to include("[ ] escaped empty checkbox")
    end

    it "preserves legacy stroked checklist markup" do
      raw = '<span class="chcklst-stroked">done</span>'

      expect(PrettyText.cook(raw)).to include('<span class="chcklst-stroked">done</span>')
    end

    it "does not allow raw HTML to forge interactive checklist controls" do
      raw = <<~MARKDOWN
        <span class="chcklst-box fa fa-square-o" data-chk-src="1:0"></span>

        `[ ]` [ ] real
      MARKDOWN
      cooked = PrettyText.cook(raw)
      nodes = Nokogiri::HTML5.fragment(cooked).css("span.chcklst-box")

      expect(nodes.map { |node| node["data-chk-src"] }).to eq(["2:1"])
      expect(cooked).to include("&lt;span")
    end

    it "counts escaped and metadata markers when assigning line ordinals" do
      raw = <<~MARKDOWN
        \\[x] escaped [x] visible
        ![](<https://example.test/[x]>)[x]
        [link](<https://example.test/[x]> "[x]") [ ] visible
      MARKDOWN

      expect(checklist_nodes(raw).map { |node| node["data-chk-src"] }).to eq(%w[0:1 1:2 2:2])
    end

    it "preserves surrounding cooked HTML while adding source hints" do
      raw = "[ ] before `[x]` [x] after"

      expect(PrettyText.cook(raw)).to eq(
        '<p><span class="chcklst-box fa fa-square-o" data-chk-src="0:0"></span> before <code>[x]</code> <span class="chcklst-box checked fa fa-square-check-o" data-chk-src="0:2"></span> after</p>',
      )
    end

    it "maps checkboxes in table header cells" do
      raw = <<~MARKDOWN
        | [ ] a | [x] b |
        |---|---|
        | c | d |
      MARKDOWN

      expect(checklist_nodes(raw).map { |node| node["data-chk-src"] }).to eq(%w[0:0 0:1])
    end

    it "maps source lines through blockquotes, lists, and tables" do
      raw = <<~MARKDOWN
        > - [ ] quoted

        | a | b |
        |---|---|
        | [x] no | [ ] go |
      MARKDOWN

      expect(checklist_nodes(raw).map { |node| node["data-chk-src"] }).to eq(%w[0:0 4:0 4:1])
    end
  end
end
