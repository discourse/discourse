# frozen_string_literal: true

require "rails_helper"

describe PrettyText do
  context "with discourse math" do
    before { SiteSetting.discourse_math_enabled = true }

    it "can handle inline math" do
      cooked = PrettyText.cook('I like $\{a,b\}\$<a>$ etc')
      html = '<p>I like <span class="math">\{a,b\}\$&lt;a&gt;</span> etc</p>'
      expect(cooked).to eq(html)
    end

    it "can correctly ignore bad blocks" do
      cooked = PrettyText.cook <<~MD
        $$a
        a
        $$"
      MD

      html = <<~HTML
        <p>$$a<br>
        a<br>
        $$"</p>
      HTML

      expect(cooked).to eq(html.strip)
    end

    it "can handle inline edge cases" do
      expect(PrettyText.cook ",$+500\\$").not_to include("math")
      expect(PrettyText.cook "$+500$").to include("math")
      expect(PrettyText.cook ",$+500$,").to include("math")
      expect(PrettyText.cook "200$ + 500$").not_to include("math")
      expect(PrettyText.cook ",$+500$x").not_to include("math")
      expect(PrettyText.cook "y$+500$").not_to include("math")
      expect(PrettyText.cook "($ +500 $)").to include("math")
    end

    it "can handle inline math with Chinese punctuation" do
      cooked = PrettyText.cook("这是一个测试，$a^2 + b^2 = c^2$，这是另一个测试。")
      html = '<p>这是一个测试，<span class="math">a^2 + b^2 = c^2</span>，这是另一个测试。</p>'
      expect(cooked).to eq(html)
    end

    it "can handle inline math with Japanese punctuation" do
      cooked = PrettyText.cook("これはテストです、$a^2 + b^2 = c^2$、これもテストです。")
      html = '<p>これはテストです、<span class="math">a^2 + b^2 = c^2</span>、これもテストです。</p>'
      expect(cooked).to eq(html)
    end

    it "can handle inline math with Arabic punctuation" do
      cooked = PrettyText.cook("هذا اختبار،$a^2 + b^2 = c^2$،هذا اختبار آخر.")
      html = '<p>هذا اختبار،<span class="math">a^2 + b^2 = c^2</span>،هذا اختبار آخر.</p>'
      expect(cooked).to eq(html)
    end

    it "can handle block math with Chinese punctuation" do
      cooked = PrettyText.cook("$$\na^2 + b^2 = c^2\n$$")
      html = "<div class=\"math\">\na^2 + b^2 = c^2\n</div>"
      expect(cooked.strip).to eq(html.strip)
    end

    it "can handle inline math" do
      cooked = PrettyText.cook <<~MD
        I like
        $$
        \{a,b\}\$<a>
        $$
        etc
      MD

      html = <<~HTML
        <p>I like</p>
        <div class="math">
        {a,b}$&lt;a&gt;
        </div>
        <p>etc</p>
      HTML

      expect(cooked).to eq(html.strip)
    end
  end
end
