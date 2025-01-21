# frozen_string_literal: true

require "excerpt_parser"

RSpec.describe ExcerptParser do
  it "handles nested <details> blocks" do
    html = <<~HTML.strip
      <details>
        <summary>FOO</summary>
        <details>
          <summary>BAR</summary>
          <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>
        </details>
      </details>
    HTML

    expect(ExcerptParser.get_excerpt(html, 50, {})).to match_html "▶ FOO"
    expect(ExcerptParser.get_excerpt(html, 6, {})).to match_html "▶ FOO"
    expect(ExcerptParser.get_excerpt(html, 3, {})).to match_html "▶ FOO"
    expect(ExcerptParser.get_excerpt(html, 2, {})).to match_html "▶ FO&hellip;"
  end

  it "allows <svg> with <use> inside for icons when keep_svg is true" do
    html = '<svg class="fa d-icon d-icon-folder svg-icon svg-node"><use href="#folder"></use></svg>'
    expect(ExcerptParser.get_excerpt(html, 100, { keep_svg: true })).to match_html(
      '<svg class="fa d-icon d-icon-folder svg-icon svg-node"><use href="#folder"></use></svg>',
    )
    expect(ExcerptParser.get_excerpt(html, 100, {})).to match_html("")

    html = '<svg class="blah"><use href="#folder"></use></svg>'
    expect(ExcerptParser.get_excerpt(html, 100, { keep_svg: true })).to match_html("")

    html = '<svg><use href="#folder"></use></svg>'
    expect(ExcerptParser.get_excerpt(html, 100, { keep_svg: true })).to match_html("")

    html =
      '<use href="#user"></use><svg class="fa d-icon d-icon-folder svg-icon svg-node"><use href="#folder"></use></svg>'
    expect(ExcerptParser.get_excerpt(html, 100, { keep_svg: true })).to match_html(
      '<svg class="fa d-icon d-icon-folder svg-icon svg-node"><use href="#folder"></use></svg>',
    )
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

    it "keeps the content for internal oneboxes that contain github oneboxes" do
      html = <<~HTML.strip
        <p>Another commit to test out.</p>
        <p>This time this commit has a longer commit message.</p>
        <aside class="onebox githubcommit" data-onebox-src="https://github.com/discourse/discourse/commit/90f395a11895e9cfb7edd182b0bf5ec3d51d7892">
          <header class="source">
              <a href="https://github.com/discourse/discourse/commit/90f395a11895e9cfb7edd182b0bf5ec3d51d7892" target="_blank" rel="noopener">github.com/discourse/discourse</a>
          </header>
          <article class="onebox-body">
            <div class="github-row">
          <div class="github-icon-container" title="Commit">
            <svg width="60" height="60" class="github-icon" viewBox="0 0 14 16" aria-hidden="true"><path fill-rule="evenodd" d="M10.86 7c-.45-1.72-2-3-3.86-3-1.86 0-3.41 1.28-3.86 3H0v2h3.14c.45 1.72 2 3 3.86 3 1.86 0 3.41-1.28 3.86-3H14V7h-3.14zM7 10.2c-1.22 0-2.2-.98-2.2-2.2 0-1.22.98-2.2 2.2-2.2 1.22 0 2.2.98 2.2 2.2 0 1.22-.98 2.2-2.2 2.2z"></path></svg>
          </div>
          <div class="github-info-container">
            <h4>
              <a href="https://github.com/discourse/discourse/commit/90f395a11895e9cfb7edd182b0bf5ec3d51d7892" target="_blank" rel="noopener">DEV: Skip srcset for onebox thumbnails (#22621)</a>
            </h4>
            <div class="github-info">
              <div class="date">
                committed <span class="discourse-local-date" data-format="ll" data-date="2023-07-19" data-time="18:21:34" data-timezone="UTC">06:21PM - 19 Jul 23 UTC (UTC)</span>
              </div>
              <div class="user">
                <a href="https://github.com/oblakeerickson" target="_blank" rel="noopener">
                  <img alt="oblakeerickson" src="//localhost:3000/uploads/default/original/1X/741ac99d6a66d71cdd46dd99fb5156506e13fdf2.jpeg" class="onebox-avatar-inline" width="20" height="20" data-dominant-color="3C3C3C">
                  oblakeerickson
                </a>
              </div>
              <div class="lines" title="changed 2 files with 24 additions and 15 deletions">
                <a href="https://github.com/discourse/discourse/commit/90f395a11895e9cfb7edd182b0bf5ec3d51d7892" target="_blank" rel="noopener">
                  <span class="added">+24</span>
                  <span class="removed">-15</span>
                </a>
              </div>
            </div>
          </div>
        </div>
          <div class="github-row">
            <p class="github-body-container">* DEV: Test commit message
        This is a longer commit message <span class="show-more-container"><a href="https://github.com/discourse/discourse/commit/90f395a11895e9cfb7edd182b0bf5ec3d51d7892" target="_blank" rel="noopener" class="show-more">…</a></span><span class="excerpt hidden">that has the show-more class along with the exerpt hidden class</span></p>
          </div>
          </article>
          <div class="onebox-metadata">
          </div>
          <div style="clear: both"></div>
        </aside>
      HTML
      expect(ExcerptParser.get_excerpt(html, 100, keep_onebox_body: false)).to eq(<<~HTML.strip)
        Another commit to test out. \nThis time this commit has a longer commit message.
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
      expect(ExcerptParser.get_excerpt(html, 100, keep_quotes: true)).to eq(
        "This is a quoted text.",
      )
    end
  end
end
