# frozen_string_literal: true

RSpec.describe Migrations::Importer::ContentCacheUrls do
  it "rewrites site and upload prefixes once with exact boundaries" do
    rewriter =
      described_class.new(
        { "site" => "https://old.test", "uploads" => "https://old.test/uploads" },
        { "site" => "https://new.test", "uploads" => "https://old.test/media" },
      )
    html =
      '<p>https://old.test <a href="https://old.test/t/1?x=1&amp;y=2">link</a><img src="https://old.test/uploads/a.png"><a href="https://old.test.evil/a">external</a></p>'
    result = Nokogiri::HTML5.fragment(rewriter.html(html))
    expect(result.at_css("p").text).to start_with("https://old.test")
    expect(result.css("a").map { |node| node["href"] }).to eq(
      %w[https://new.test/t/1?x=1&y=2 https://old.test.evil/a],
    )
    expect(result.at_css("img")["src"]).to eq("https://old.test/media/a.png")
  end

  it "leaves unchanged bases byte-for-byte and rejects ambiguous replacements" do
    bases = { "site" => "https://same.test" }
    html = "<a href='https://same.test/t/1'>link</a>"
    expect(described_class.new(bases, bases).html(html)).to eq(html)
    ambiguous =
      described_class.new(
        { "site" => "https://old.test", "cdn" => "https://old.test" },
        { "site" => "https://new.test", "cdn" => "https://cdn.test" },
      )
    expect { ambiguous.url("https://old.test/a") }.to raise_error(described_class::Unresolved)
    expect { described_class.new(bases, {}).url("https://same.test/a") }.to raise_error(
      described_class::Unresolved,
    )
  end

  it "rewrites srcset and Markdown destinations while preserving code" do
    rewriter =
      described_class.new(
        { "site" => "https://old.test", "schemeless" => "//old.test" },
        { "site" => "https://new.test", "schemeless" => "//new.test" },
      )
    html = '<img srcset="https://old.test/a.png 1x, //old.test/b.png 2x">'
    expect(Nokogiri::HTML5.fragment(rewriter.html(html)).at_css("img")["srcset"]).to eq(
      "https://new.test/a.png 1x, //new.test/b.png 2x",
    )
    raw = "[link](https://old.test/a) `https://old.test/code`\n```\nhttps://old.test/fenced\n```"
    expect(rewriter.raw(raw)).to eq(
      "[link](https://new.test/a) `https://old.test/code`\n```\nhttps://old.test/fenced\n```",
    )
  end

  it "keeps query values and HTML code intact and supports relative upload destinations" do
    rewriter =
      described_class.new(
        { "site" => "https://old.test", "uploads" => "/uploads/source" },
        { "site" => "https://new.test", "uploads" => "/uploads/destination" },
      )
    external = "https://external.test/?redirect=https://old.test/t/1"
    expect(rewriter.url(external)).to eq(external)
    raw = "[file](/uploads/source/a.png) <code>https://old.test/example</code>"
    expect(rewriter.raw(raw)).to eq(
      "[file](/uploads/destination/a.png) <code>https://old.test/example</code>",
    )
  end

  it "rewrites relative reference definitions and HTML attributes without cascading" do
    rewriter =
      described_class.new(
        { "uploads" => "/uploads/source", "other" => "/uploads/destination" },
        { "uploads" => "/uploads/destination", "other" => "/uploads/third" },
      )
    raw = "[attachment]: /uploads/source/a.png\n<img src='/uploads/source/b.png'>"
    expect(rewriter.raw(raw)).to eq(
      "[attachment]: /uploads/destination/a.png\n<img src='/uploads/destination/b.png'>",
    )
  end
end
