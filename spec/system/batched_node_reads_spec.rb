# frozen_string_literal: true
RSpec.describe "System browser element reads" do
  let(:browser_page) { page.driver.with_playwright_page(&:itself) }

  before do
    browser_page.set_content(<<~HTML)
      <div id="plain">Visible</div>
      <div style="display:none"><span id="hidden">Hidden</span></div>
      <div style="visibility:hidden"><span id="restored" style="visibility:visible">Visible</span></div>
      <div style="opacity:0"><span id="transparent">Hidden</span></div>
      <details><summary id="summary">Summary</summary><div id="closed">Hidden</div></details>
      <details open><div id="open">Visible</div></details>
      <div id="text">  First&nbsp;line<br><br>Second line  <span style="display:none">Hidden</span></div>
      <textarea id="textarea">Original</textarea>
      <svg><text id="svg">Vector text</text></svg>
      <map name="present"><area id="area" shape="rect" coords="0,0,5,5"></map><img usemap="#present">
      <map name="absent"><area id="missing-image" shape="rect" coords="0,0,5,5"></map>
      <div id="shadow-host"></div>
    HTML
    browser_page.evaluate(<<~JS)
      () => {
        document.querySelector('#shadow-host').attachShadow({ mode: 'open' }).innerHTML = '<span id="shadow">Shadow</span>';
        document.querySelector('#textarea').value = 'Edited';
      }
    JS
  end

  describe "#visible?" do
    it "preserves visibility across hidden ancestors, details, image maps and shadow roots" do
      expect(
        %w[
          plain
          hidden
          restored
          transparent
          summary
          closed
          open
          area
          missing-image
          shadow
        ].map { |id| node_for(id).visible? },
      ).to eq([true, false, true, false, true, false, true, true, false, true])
    end
  end

  describe "#visible_text" do
    it "normalizes rendered text and preserves textarea and SVG text semantics" do
      expect(%w[text hidden textarea svg shadow].map { |id| node_for(id).visible_text }).to eq(
        ["First line\nSecond line", "", "Original", "Vector text", "Shadow"],
      )
    end
  end

  %i[visible? visible_text].each do |read_method|
    describe "##{read_method}" do
      it "rejects an element removed from the document" do
        node = node_for("plain")
        browser_page.evaluate("() => document.querySelector('#plain').remove()")

        expect { node.public_send(read_method) }.to raise_error(
          Capybara::Playwright::Node::StaleReferenceError,
        )
      end

      it "rejects an element from a previous document" do
        node = node_for("plain")
        browser_page.goto("data:text/html,<p>New document</p>")

        expect { node.public_send(read_method) }.to raise_error(
          Capybara::Playwright::Node::StaleReferenceError,
        )
      end
    end
  end

  private

  def node_for(id)
    Capybara::Playwright::Node.new(nil, nil, browser_page, browser_page.query_selector("##{id}"))
  end
end
