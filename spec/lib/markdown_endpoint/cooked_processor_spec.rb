# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarkdownEndpoint::CookedProcessor do
  describe ".to_markdown" do
    it "converts GFM structures and Discourse elements" do
      html = <<~HTML
        <h2>Heading</h2>
        <p>Hello <strong>world</strong> <a class="mention" href="/u/sam">@sam</a>
        <a class="hashtag-cooked" href="/tag/ruby">#ruby</a>
        <img class="emoji" title=":wave:" src="/images/emoji.png"></p>
        <table><thead><tr><th>Name</th><th>Value</th></tr></thead><tbody><tr><td>A</td><td>1</td></tr></tbody></table>
        <pre><code class="lang-ruby">puts "ok"</code></pre>
        <details><summary>More</summary><p>Nested <em>content</em></p></details>
        <div class="poll" data-poll-title="Choose one"></div>
      HTML

      markdown = described_class.to_markdown(html)

      expect(markdown).to include("## Heading", "**world**", "@sam", "#ruby", ":wave:")
      expect(markdown).to include("| Name | Value |", 'puts "ok"')
      expect(markdown).to include("> **More**", "_Poll: Choose one (view on site)_")
    end

    it "preserves quotes, oneboxes, lightboxes, and nested formatting" do
      html = <<~HTML
        <aside class="quote" data-username="alice">
          <div class="title"><a href="/t/topic/1/2">alice:</a></div>
          <blockquote><p>A <strong>nested</strong> quote</p></blockquote>
        </aside>
        <aside class="onebox"><h3><a href="https://example.com/x">Example [title]</a></h3><article class="onebox-body"><p>An excerpt</p></article></aside>
        <a class="lightbox" href="/uploads/original.png"><img alt="alt text" src="/uploads/small.png"></a>
      HTML

      markdown = described_class.to_markdown(html)

      expect(markdown).to include("> [@alice](#{Discourse.base_url}/t/topic/1/2):")
      expect(markdown).to include("> A **nested** quote")
      expect(markdown).to include("> **[Example \\[title\\]](https://example.com/x)**")
      expect(markdown).to include("![alt text](#{Discourse.base_url}/uploads/original.png)")
    end

    it "escapes every line of plain onebox excerpts" do
      html = <<~HTML
        <aside class="onebox">
          <h3><a href="https://example.test/source">Source</a></h3>
          <article class="onebox-body"><p># Heading<br>[click](https://example.test)</p></article>
        </aside>
      HTML

      markdown = described_class.to_markdown(html)

      expect(markdown).to include("> \\# Heading", "> \\[click\\](https://example.test)")
      expect(markdown).not_to include("\n> # Heading", "\n> [click](https://example.test)")
    end

    it "uses longer code fences locally while preserving language and nested blocks" do
      html = <<~HTML
        <pre><code class="lang-ruby">puts "``` and ````"
        &lt;literal-tag&gt;</code></pre>
        <aside class="quote" data-username="alice">
          <blockquote><pre><code class="language-ruby">inside ``` quote</code></pre></blockquote>
        </aside>
        <details><summary>Code details</summary><pre><code>inside ```` details</code></pre></details>
      HTML

      markdown = described_class.to_markdown(html)

      expect(markdown).to include("`````ruby", 'puts "``` and ````"', "<literal-tag>")
      expect(markdown).to include("> ````ruby", "> inside ``` quote", "> `````")
      expect(markdown).to include("> **Code details**", "> `````", "> inside ```` details")
    end

    it "handles malformed and empty HTML without raising" do
      expect(described_class.to_markdown("<p>unfinished <strong>tag")).to include("unfinished")
      expect(described_class.to_markdown(nil)).to eq("")
    end
  end
end
