# frozen_string_literal: true

# Cross-checks the uploads the extractor finds inside raw HTML against the ones
# core finds there. Core rewrites an `upload://` source it cannot resolve into a
# placeholder image carrying `data-orig-src`, so the set of those attributes in
# the cooked HTML is the exact set of uploads a raw tag contributes — the oracle
# every row is measured against. Needs a booted Rails environment, so it is
# tagged `:rails` and runs only under `MIGRATIONS_RAILS=1`.
RSpec.describe Migrations::Converters::Discourse::RawExtractor, :rails do
  include_context "with parity extractor"

  def short
    "upload://2Yjf3WE4KOQ88YUb4fUMubKB9My.png"
  end

  def other
    "upload://k9k7D6IBBk6Sg7EuRM59QL72xXn.png"
  end

  # Each row is [label, raw].
  def rows
    [
      ["tag in a paragraph", %{before <img src="#{short}"> after}],
      ["tag on a line of its own", %{intro\n\n<img src="#{short}">\n\noutro}],
      ["tag inside a block element", %{<div>\n<img src="#{short}">\n</div>}],
      ["two tags in one block", %{<div>\n<img src="#{short}">\n<img src="#{other}">\n</div>}],
      ["the same upload in two tags", %{<img src="#{short}"> <img src="#{short}">}],
      ["single-quoted source", %{<img src='#{short}'>}],
      ["unquoted source", %{<img src=#{short}>}],
      ["source among other attributes", %{<img alt="a photo" src="#{short}" width="690">}],
      ["source before other attributes", %{<img src="#{short}" alt="a photo">}],
      ["uppercase tag and attribute", %{<IMG SRC="#{short}">}],
      ["attributes on lines of their own", %{<img\n  src="#{short}"\n  alt="a photo"\n>}],
      ["tag inside a list item", %{- item\n\n  <img src="#{short}">}],
      ["tag inside a markdown quote", %{> quoted\n>\n> <img src="#{short}">}],
      ["tag next to a markdown image", %{![a](#{short}) <img src="#{short}">}],
      ["tag next to a markdown image of another upload", %{![a](#{other}) <img src="#{short}">}],
      ["tag in a fence", %{```\n<img src="#{short}">\n```}],
      ["tag in a code span", %{a `<img src="#{short}">` b}],
      ["tag in an indented block", %{intro\n\n    <img src="#{short}">}],
      ["tag in a code block element", %{<pre>\n<img src="#{short}">\n</pre>}],
      ["link instead of an image", %{<a href="#{short}">file</a>}],
      ["source on a tag core has no upload rule for", %{<video poster="#{short}"></video>}],
      ["fenced tag beside a live one", %{<img src="#{short}">\n\n```\n<img src="#{short}">\n```}],
      ["code span beside a live tag", %{`#{short}` <img src="#{short}">}],
    ]
  end

  # The short URL of every upload the extractor recorded. A row may also hold a
  # markdown image, whose recorded source is the whole `![…](…)` construct, so
  # the URL is read out of it to compare like with like.
  def extracted_uploads(raw)
    buffer = new_buffer
    build_extractor(buffer).extract(raw)
    buffer.uploads.filter_map { |upload| upload[:original_markdown][%r{upload://[^\s)"'<>]+}] }.sort
  end

  def cooked_uploads(raw)
    PrettyText.cook(raw).scan(%r{data-orig-src="(upload://[^"]*)"}).flatten.sort
  end

  it "finds the uploads of a raw tag exactly where core finds them" do
    deviations =
      rows.filter_map do |label, raw|
        extracted = extracted_uploads(raw)
        cooked = cooked_uploads(raw)
        next if extracted == cooked

        "#{label} (#{raw.inspect}): extractor=#{extracted.inspect} core=#{cooked.inspect}"
      end

    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  # Rows that cook to nothing agree with an extractor that defers nothing, so
  # the battery only says something as long as both answers occur.
  it "holds rows core keeps an upload for and rows it does not" do
    keeping, dropping = rows.partition { |_, raw| cooked_uploads(raw).any? }

    expect(keeping.size).to be > 0
    expect(dropping.size).to be > 0
  end
end
