# frozen_string_literal: true

RSpec.describe HashtagRewriter do
  def rewrite(raw, from: "alpha", to: "beta", cook_options: {})
    described_class.new(raw, cook_options).rewrite { |ref| to if ref.casecmp?(from) }
  end

  it "rewrites a plain reference" do
    expect(rewrite("See #alpha here.")).to eq("See #beta here.")
  end

  it "leaves references the markdown pipeline would not cook" do
    protected_raws = {
      "fenced code" => "Live #alpha\n\n```\nfenced #alpha\n```",
      "fenced code with a language" => "Live #alpha\n\n```ruby\nfenced #alpha\n```",
      "tilde fence" => "Live #alpha\n\n~~~\nfenced #alpha\n~~~",
      "unclosed fence" => "Live #alpha\n\n```\nfenced #alpha",
      "inline code" => "Live #alpha and `inline #alpha`",
      "double backtick span" => "Live #alpha and ``inline #alpha``",
      "indented code" => "Live #alpha\n\n    indented #alpha",
      "code bbcode" => "Live #alpha and [code]bbcode #alpha[/code]",
      "link text" => "Live #alpha and [#alpha](https://example.com/)",
      "link destination" => "Live #alpha and [x](https://example.com/#alpha)",
      "autolink" => "Live #alpha and <https://example.com/#alpha>",
      "linkified url fragment" => "Live #alpha and https://example.com/?tab=#alpha",
      "image alt" => "Live #alpha and ![#alpha](https://example.com/a.png)",
      "html attribute" => %{Live #alpha and <div data-x="#alpha">x</div>},
    }

    protected_raws.each do |name, raw|
      expect(rewrite(raw)).to eq(raw.sub("Live #alpha", "Live #beta")),
      "expected #{name} to be left alone"
    end
  end

  it "rewrites references the markdown pipeline does cook" do
    live_raws = {
      "blockquote" => "> quoted #alpha",
      "quote bbcode" => "[quote]quoted #alpha[/quote]",
      "heading" => "## heading #alpha",
      "list item" => "- item #alpha",
      "table cell" => "| a |\n| --- |\n| #alpha |",
      "bold" => "**bold #alpha**",
      "details" => "[details=x]inner #alpha[/details]",
      "unclosed backtick" => "unclosed `#alpha",
    }

    live_raws.each do |name, raw|
      expect(rewrite(raw)).to eq(raw.sub("#alpha", "#beta")), "expected #{name} to be rewritten"
    end
  end

  it "matches whole references, so a longer reference is untouched" do
    expect(rewrite("I use #alpha.js daily and #alpha rarely.")).to eq(
      "I use #alpha.js daily and #beta rarely.",
    )
  end

  it "does not read a non-ascii neighbour as part of an ascii reference" do
    expect(rewrite("One #alpha and two #alphaé here.", from: "alpha")).to eq(
      "One #beta and two #alphaé here.",
    )
  end

  it "matches case-insensitively when the caller asks it to" do
    expect(rewrite("See #ALPHA here.")).to eq("See #beta here.")
  end

  it "handles a raw with every context at once" do
    raw = <<~MD
      Live #alpha here.

      ```
      fence #alpha
      ```

      Inline `#alpha` span.

      [#alpha](https://example.com/) and https://example.com/?tab=#alpha

          indented #alpha

      <div data-x="#alpha">html</div>

      > quoted #alpha is live
    MD

    result = rewrite(raw)

    expect(result.scan("#beta").size).to eq(2)
    expect(result).to include("Live #beta here.", "> quoted #beta is live")
    expect(result).to include("fence #alpha", "`#alpha`", "?tab=#alpha", "    indented #alpha")
  end

  it "respects the cook options it is given" do
    raw = "and `inline #alpha` here"

    expect(rewrite(raw)).to eq(raw)
    expect(rewrite(raw, cook_options: { markdown_it_rules: %w[table] })).to eq(
      "and `inline #beta` here",
    )
  end

  it "leaves everything alone when the block never asks for a replacement" do
    raw = "See #alpha and #gamma here."

    expect(described_class.new(raw).rewrite { nil }).to eq(raw)
  end

  describe "parity with the markdown pipeline" do
    it "ports the matcher the cooker uses" do
      js = File.read("frontend/discourse-markdown-it/src/features/hashtag-autocomplete.js")
      matcher = js[%r{matcher:\s*(/.+/),?\n}, 1]

      expect(matcher).to be_present

      ported =
        matcher[1..-2]
          .gsub(/\\u([0-9A-Fa-f]{4})/) { [Regexp.last_match(1).hex].pack("U") }
          .gsub("\\/", "/")

      expect(described_class::REF).to eq(ported[/#\((.+)\)\z/, 1])
    end

    it "agrees with the cooker about which references become hashtags" do
      Fabricate(:tag, name: "alpha")

      corpus = [
        "plain #alpha",
        "#alpha.js and #alpha",
        "a#alpha and #alpha",
        "/#alpha and #alpha",
        "x:#alpha",
        "##alpha",
        "(#alpha)",
        "#alpha, #alpha and #alpha",
      ]

      corpus.each do |raw|
        cooked = PrettyText.cook(raw)
        anchors = cooked.scan(/class="hashtag-cooked"/).size
        matched = raw.scan(described_class::HASHTAG).flatten.count { |ref| ref == "alpha" }

        expect(matched).to eq(anchors), "mismatch for #{raw.inspect}"
      end
    end
  end

  describe ".usable_ref?" do
    it "accepts references the matcher can read back" do
      expect(described_class.usable_ref?("node.js")).to eq(true)
      expect(described_class.usable_ref?("café")).to eq(true)
      expect(described_class.usable_ref?("support:bucks")).to eq(true)
    end

    it "rejects references that would not survive a round trip" do
      expect(described_class.usable_ref?("")).to eq(false)
      expect(described_class.usable_ref?(nil)).to eq(false)
      expect(described_class.usable_ref?("has space")).to eq(false)
      expect(described_class.usable_ref?("trailing.")).to eq(false)
    end
  end
end
