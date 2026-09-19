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

  it "rewrites references bounded by unicode symbols, like the cooker does" do
    expect(rewrite("€#alpha and #alpha")).to eq("€#beta and #beta")
    expect(rewrite("#alpha™ and #alpha")).to eq("#beta™ and #beta")
  end

  it "leaves character references alone" do
    expect(rewrite("hi #123 and &#123;", from: "123", to: "456")).to eq("hi #456 and &#123;")
    expect(rewrite("hi #x1f600 and &#x1f600;", from: "x1f600", to: "grin")).to eq(
      "hi #grin and &#x1f600;",
    )
  end

  it "rewrites lookalikes the cooker does not read as character references" do
    expect(rewrite("&#123", from: "123", to: "456")).to eq("&#456")
    expect(rewrite("&amp;#123;", from: "123", to: "456")).to eq("&amp;#456;")
  end

  it "leaves reference link labels alone" do
    labelled_raws = {
      "full reference" => "Here is #alpha\n\n[link][#alpha]\n\n[#alpha]: https://example.com/",
      "collapsed reference" => "Here is #alpha\n\n[#alpha][]\n\n[#alpha]: https://example.com/",
      "shortcut reference" => "Here is #alpha\n\n[#alpha]\n\n[#alpha]: https://example.com/",
      "image reference" => "Here is #alpha\n\n![x][#alpha]\n\n[#alpha]: https://example.com/a.png",
    }

    labelled_raws.each do |name, raw|
      expect(rewrite(raw)).to eq(raw.sub("Here is #alpha", "Here is #beta")),
      "expected #{name} labels to be left alone"
    end
  end

  it "rewrites a bracketed reference that resolves to no link" do
    expect(rewrite("[#alpha] fix crash")).to eq("[#beta] fix crash")
  end

  it "rewrites inside a dead reference link, whose text stays visible" do
    raw = "[see #alpha here][#u1]\n\n[#u2]: https://example.com/"

    expect(rewrite(raw)).to eq("[see #beta here][#u1]\n\n[#u2]: https://example.com/")
  end

  it "leaves footnote labels alone" do
    raw = "a [^#alpha] b\n\n[^#alpha]: note"

    expect(rewrite(raw)).to eq(raw)
  end

  it "leaves a reference the linkifier consumes alone" do
    expect(rewrite("see #docs.example.com now", from: "docs.example.com", to: "guides")).to eq(
      "see #docs.example.com now",
    )
  end

  it "leaves a reference the emphasis parser consumes alone" do
    expect(rewrite("x #_alpha_ y", from: "_alpha_", to: "under")).to eq("x #_alpha_ y")
  end

  it "leaves a reference the typographer splits alone" do
    expect(rewrite("x #alpha--z y", from: "alpha--z", to: "dashed")).to eq("x #alpha--z y")
  end

  it "leaves occurrences that render nothing alone" do
    fence = "```#alpha\ncode\n```"
    orphan_definition = "[#alpha]: https://example.com/"

    expect(rewrite(fence)).to eq(fence)
    expect(rewrite(orphan_definition)).to eq(orphan_definition)
  end

  it "does not read a non-ascii neighbour as part of an ascii reference" do
    expect(rewrite("One #alpha and two #alphaé here.")).to eq("One #beta and two #alphaé here.")
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
        "€#alpha and #alpha™",
        "#alpha, #alpha and #alpha",
      ]

      corpus.each do |raw|
        cooked = PrettyText.cook(raw)
        anchors = cooked.scan(/class="hashtag-cooked"/).size
        matched = PrettyText.scan_hashtags(raw).count { |ref| ref == "alpha" }

        expect(matched).to eq(anchors), "mismatch for #{raw.inspect}"
      end
    end
  end

  describe ".sql_like_pattern" do
    it "escapes LIKE wildcards" do
      expect(described_class.sql_like_pattern("a_b%c\\d")).to eq("%#a\\_b\\%c\\\\d%")
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
