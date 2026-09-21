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

      expect(markdown).to include("## Heading", "**world**", "@sam", "#ruby", "👋")
      expect(markdown).to include("| Name | Value |", 'puts "ok"')
      expect(markdown).to include("> **More**", "_Poll: Choose one_")
    end

    it "converts standard emoji, aliases, and skin tones to Unicode" do
      html = PrettyText.cook(":smile: :+1: :wave:t4: :thumbsup:t6:")

      expect(described_class.to_markdown(html)).to eq("😄 👍 👋🏽 👍🏿")
    end

    it "preserves custom and unknown emoji shortcodes" do
      html = <<~HTML
        <p><img class="emoji emoji-custom" title=":custom_emoji:" src="/custom.png">
        <img class="emoji" alt=":unknown_emoji:" src="/emoji.png"></p>
      HTML

      expect(described_class.to_markdown(html)).to eq(":custom_emoji::unknown_emoji:")
    end

    it "preserves literal shortcodes in code and URLs" do
      html = <<~HTML
        <p><code>:smile:</code> <a href="https://example.com/:wave:">Example</a></p>
        <pre><code>:wave:t4:</code></pre>
      HTML

      expect(described_class.to_markdown(html)).to eq(
        "`:smile:` [Example](https://example.com/:wave:)\n\n```\n:wave:t4:\n```",
      )
    end

    it "keeps footnote markers and formatted definitions without dead fragment links" do
      html = <<~HTML
        <p>Some text<sup class="footnote-ref"><a href="#footnote-123-1" id="footnote-ref-123-1">[1]</a></sup>.</p>
        <p>Repeated<sup class="footnote-ref"><a href="#footnote-123-1" id="footnote-ref-123-1:1">[1:1]</a></sup>.</p>
        <section class="footnotes"><ol class="footnotes-list">
          <li id="footnote-123-1" class="footnote-item"><p>A <strong>formatted</strong> note with a <a href="https://example.com">source</a> <a href="#footnote-ref-123-1" class="footnote-backref">↩︎</a> <a href="#footnote-ref-123-1:1" class="footnote-backref">↩︎</a></p></li>
        </ol></section>
      HTML

      markdown = described_class.to_markdown(html)

      expect(markdown).to include("Some text\\[1\\].", "Repeated\\[1:1\\].")
      expect(markdown).to include("1. A **formatted** note with a [source](https://example.com)")
      expect(markdown).not_to match(/\]\(#footnote|↩︎/)
    end

    it "links named and unnamed polls, including nested polls, to their post" do
      html = <<~HTML
        <div class="poll" data-poll-title="Choose [one]"></div>
        <details><summary>More</summary><div class="poll"></div></details>
      HTML
      post_url = "#{Discourse.base_url}/t/topic/123/2"

      markdown = described_class.to_markdown(html, post_url:)

      expect(markdown).to include("_Poll: Choose \\[one\\] ([view on site](#{post_url}))_")
      expect(markdown).to include("> _Poll ([view on site](#{post_url}))_")
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
