# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseMath::MathRenderer do
  describe ".validate!" do
    it "raises for blank expressions" do
      expect { described_class.validate!("") }.to raise_error(
        DiscourseMath::MathRenderer::ValidationError,
        "Expression cannot be blank",
      )
      expect { described_class.validate!(nil) }.to raise_error(
        DiscourseMath::MathRenderer::ValidationError,
        "Expression cannot be blank",
      )
    end

    it "raises for expressions exceeding max length" do
      long_expression = "x" * (DiscourseMath::MathRenderer::MAX_EXPRESSION_LENGTH + 1)
      expect { described_class.validate!(long_expression) }.to raise_error(
        DiscourseMath::MathRenderer::ValidationError,
        /exceeds maximum length/,
      )
    end

    it "raises for dangerous patterns" do
      dangerous_expressions = %w[
        <script>alert('xss')</script>
        javascript:alert(1)
        onclick=alert(1)
        data:text/html,<script>
      ]

      dangerous_expressions.each do |expr|
        expect { described_class.validate!(expr) }.to raise_error(
          DiscourseMath::MathRenderer::ValidationError,
          /potentially dangerous/,
        )
      end
    end

    it "accepts valid math expressions" do
      valid_expressions = [
        "E = mc^2",
        "\\frac{1}{2}",
        "\\sum_{i=1}^{n} x_i",
        "\\int_0^\\infty e^{-x^2} dx",
        "x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}",
      ]

      valid_expressions.each { |expr| expect(described_class.validate!(expr)).to be true }
    end
  end

  describe ".valid?" do
    it "returns true for valid expressions" do
      expect(described_class.valid?("E = mc^2")).to be true
    end

    it "returns false for invalid expressions" do
      expect(described_class.valid?("")).to be false
      expect(described_class.valid?("<script>")).to be false
    end
  end

  describe ".sanitize" do
    it "removes null bytes and control characters" do
      expect(described_class.sanitize("x\x00y")).to eq("xy")
      expect(described_class.sanitize("a\x1Fb")).to eq("ab")
    end

    it "preserves newlines and tabs" do
      expect(described_class.sanitize("a\nb")).to eq("a\nb")
      expect(described_class.sanitize("a\tb")).to eq("a\tb")
    end

    it "normalizes line endings" do
      expect(described_class.sanitize("a\r\nb")).to eq("a\nb")
      expect(described_class.sanitize("a\rb")).to eq("a\nb")
    end

    it "strips leading and trailing whitespace" do
      expect(described_class.sanitize("  x^2  ")).to eq("x^2")
    end

    it "returns empty string for blank input" do
      expect(described_class.sanitize("")).to eq("")
      expect(described_class.sanitize(nil)).to eq("")
    end
  end

  describe ".extract_math_expressions" do
    it "extracts inline math from span.math elements" do
      html = '<p>Hello <span class="math">E=mc^2</span> world</p>'
      expressions = described_class.extract_math_expressions(html)

      expect(expressions.length).to eq(1)
      expect(expressions[0][:expression]).to eq("E=mc^2")
      expect(expressions[0][:type]).to eq(:inline)
    end

    it "extracts block math from div.math elements" do
      html = '<div class="math">\\frac{1}{2}</div>'
      expressions = described_class.extract_math_expressions(html)

      expect(expressions.length).to eq(1)
      expect(expressions[0][:expression]).to eq("\\frac{1}{2}")
      expect(expressions[0][:type]).to eq(:block)
    end

    it "extracts asciimath expressions" do
      html = '<span class="asciimath">sum_(i=1)^n i</span>'
      expressions = described_class.extract_math_expressions(html)

      expect(expressions.length).to eq(1)
      expect(expressions[0][:expression]).to eq("sum_(i=1)^n i")
      expect(expressions[0][:type]).to eq(:asciimath)
    end

    it "extracts multiple expressions" do
      html = <<~HTML
        <p>Inline: <span class="math">a^2</span></p>
        <div class="math">b^2</div>
        <span class="asciimath">c^2</span>
      HTML

      expressions = described_class.extract_math_expressions(html)
      expect(expressions.length).to eq(3)
    end

    it "returns empty array for blank input" do
      expect(described_class.extract_math_expressions("")).to eq([])
      expect(described_class.extract_math_expressions(nil)).to eq([])
    end

    it "returns empty array for HTML without math" do
      html = "<p>No math here</p>"
      expect(described_class.extract_math_expressions(html)).to eq([])
    end
  end

  describe ".contains_math?" do
    it "returns true when math is present" do
      expect(described_class.contains_math?('<span class="math">x</span>')).to be true
      expect(described_class.contains_math?('<div class="math">x</div>')).to be true
      expect(described_class.contains_math?('<span class="asciimath">x</span>')).to be true
    end

    it "returns false when no math is present" do
      expect(described_class.contains_math?("<p>No math</p>")).to be false
      expect(described_class.contains_math?("")).to be false
      expect(described_class.contains_math?(nil)).to be false
    end
  end

  describe ".cache_key" do
    it "generates consistent keys for same input" do
      key1 = described_class.cache_key("E=mc^2", provider: "mathjax")
      key2 = described_class.cache_key("E=mc^2", provider: "mathjax")
      expect(key1).to eq(key2)
    end

    it "generates different keys for different expressions" do
      key1 = described_class.cache_key("a^2")
      key2 = described_class.cache_key("b^2")
      expect(key1).not_to eq(key2)
    end

    it "generates different keys for different providers" do
      key1 = described_class.cache_key("x", provider: "mathjax")
      key2 = described_class.cache_key("x", provider: "katex")
      expect(key1).not_to eq(key2)
    end

    it "generates different keys for different display modes" do
      key1 = described_class.cache_key("x", display_mode: true)
      key2 = described_class.cache_key("x", display_mode: false)
      expect(key1).not_to eq(key2)
    end

    it "includes prefix in key" do
      key = described_class.cache_key("x")
      expect(key).to start_with("discourse_math:rendered:")
    end
  end

  describe "caching" do
    let(:expression) { "E=mc^2" }
    let(:rendered_html) { '<span class="katex">rendered</span>' }
    let(:options) { { provider: "katex" } }

    after { described_class.clear_cache(expression, options) }

    it "stores and retrieves from cache" do
      expect(described_class.from_cache(expression, options)).to be_nil

      described_class.to_cache(expression, rendered_html, options)

      expect(described_class.from_cache(expression, options)).to eq(rendered_html)
    end

    it "clears cache" do
      described_class.to_cache(expression, rendered_html, options)
      expect(described_class.from_cache(expression, options)).to eq(rendered_html)

      described_class.clear_cache(expression, options)
      expect(described_class.from_cache(expression, options)).to be_nil
    end
  end

  describe ".render" do
    it "returns nil for blank expressions" do
      expect(described_class.render("")).to be_nil
      expect(described_class.render(nil)).to be_nil
    end

    it "validates expressions before rendering" do
      expect { described_class.render("<script>") }.to raise_error(
        DiscourseMath::MathRenderer::ValidationError,
      )
    end

    it "returns nil for valid expressions (client-side rendering)" do
      expect(described_class.render("E=mc^2")).to be_nil
    end
  end

  describe ".stats" do
    before do
      SiteSetting.discourse_math_enabled = true
      SiteSetting.discourse_math_provider = "mathjax"
      SiteSetting.discourse_math_enable_asciimath = true
      SiteSetting.discourse_math_enable_accessibility = false
    end

    it "returns current settings" do
      stats = described_class.stats
      expect(stats[:enabled]).to be true
      expect(stats[:provider]).to eq("mathjax")
      expect(stats[:asciimath_enabled]).to be true
      expect(stats[:accessibility_enabled]).to be false
    end
  end
end
