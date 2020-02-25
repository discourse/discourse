# frozen_string_literal: true

require "rails_helper"
require "excerpt_parser"

describe ExcerptParser do

  it "handles nested <details> blocks" do
    html = <<~HTML.strip
      <details>
      <summary>
      FOO</summary>
      <details>
      <summary>
      BAR</summary>
      <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce ultrices, ex bibendum vestibulum vestibulum, mi velit pulvinar risus, sed consequat eros libero in eros. Fusce luctus mattis mauris, vitae semper lorem sodales quis. Donec pellentesque lacus ac ante aliquam, tincidunt iaculis risus interdum. In ullamcorper cursus massa ut lacinia. Donec quis diam finibus, rutrum odio eu, maximus leo. Nulla facilisi. Nullam suscipit quam et bibendum sagittis. Praesent sollicitudin neque at luctus ornare. Maecenas tristique dapibus risus, ac dictum ipsum gravida aliquam. Phasellus vehicula eu arcu sed imperdiet. Vestibulum ornare eros a nisi faucibus vehicula. Quisque congue placerat nulla, nec finibus nulla ultrices vitae. Quisque ac mi sem. Curabitur eu porttitor justo. Etiam dignissim in orci iaculis congue. Donec tempus cursus orci, a placerat elit varius nec.</p>
      </details>
      </details>
    HTML

    expect(ExcerptParser.get_excerpt(html, 50, {})).to match_html(<<~HTML)
      <details><summary>FOO</summary>BAR
      Lorem ipsum dolor sit amet, consectetur adi&hellip;</details>
    HTML

    expect(ExcerptParser.get_excerpt(html, 6, {})).to match_html('<details><summary>FOO</summary>BAR&hellip;</details>')
    expect(ExcerptParser.get_excerpt(html, 3, {})).to match_html('<details class="disabled"><summary>FOO</summary></details>')
  end

  it "respects length parameter for <details> block" do
    html = '<details><summary>foo</summary><p>bar</p></details>'
    expect(ExcerptParser.get_excerpt(html, 100, {})).to match_html('<details><summary>foo</summary>bar</details>')
    expect(ExcerptParser.get_excerpt(html, 5, {})).to match_html('<details><summary>foo</summary>ba&hellip;</details>')
    expect(ExcerptParser.get_excerpt(html, 3, {})).to match_html('<details class="disabled"><summary>foo</summary></details>')
    expect(ExcerptParser.get_excerpt(html, 2, {})).to match_html('<details class="disabled"><summary>fo&hellip;</summary></details>')
  end

  describe "keep_onebox_body parameter" do
    it "keeps the body content for external oneboxes" do
      html = <<~HTML.strip
        <aside class="onebox">
          <header class="source">
            <img src="https://github.githubassets.com/favicon.ico" class="site-icon" width="32" height="32">
            <a href="https://github.com/discourse/discourse" target="_blank">GitHub</a>
          </header>
          <article class="onebox-body">
            <img src="/uploads/default/original/1X/10c0f1565ee5b6ca3fe43f3183529bc0afd26003.jpeg" class="thumbnail">
            <h3>
              <a href="https://github.com/discourse/discourse" target="_blank">discourse/discourse</a>
            </h3>
            <p>A platform for community discussion. Free, open, simple. - discourse/discourse</p>
          </article>
        </aside>
      HTML
      expect(ExcerptParser.get_excerpt(html, 100, keep_onebox_body: true)).to eq(<<~HTML.strip)
        [image]

        <a href="https://github.com/discourse/discourse" target="_blank">discourse/discourse</a>

        A platform for community discussion. Free, o&hellip;
      HTML
    end

    it "keeps the content for internal oneboxes" do
      html = <<~HTML.strip
        <aside class="quote" data-post="1" data-topic="8">
          <div class="title">
            <div class="quote-controls"></div>
            <img width="20" height="20" src="/user_avatar/localhost/system/40/2_2.png" class="avatar">
            <a href="/t/welcome-to-discourse/8/1">Welcome to Discourse</a>
          </div>
          <blockquote>The first paragraph of this pinned topic will be visible as a welcome message to all new visitors on your homepage.</blockquote>
        </aside>
      HTML
      expect(ExcerptParser.get_excerpt(html, 100, keep_onebox_body: true)).to eq(<<~HTML.strip)
        [image]

        <a href="/t/welcome-to-discourse/8/1">Welcome to Discourse</a>

        The first paragraph of this pinned topic will be &hellip;
      HTML
    end
  end

  describe "keep_quotes parameter" do
    it "should keep the quoted content in html" do
      html = <<~HTML.strip
        <aside class="quote">
          <blockquote>
            This is a quoted text.
          </blockquote>
        </aside>
      HTML
      expect(ExcerptParser.get_excerpt(html, 100, keep_quotes: true)).to eq("This is a quoted text.")
    end
  end
end
