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
end
