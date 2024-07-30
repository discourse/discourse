# frozen_string_literal: true

describe PrettyText do
  before { Jobs.run_immediately! }

  it "can be disabled" do
    SiteSetting.enable_markdown_footnotes = false

    markdown = <<~MD
      Here is a footnote, [^1]

      [^1]: I am one
    MD

    html = <<~HTML
      <p>Here is a footnote, [^1]</p>\n<p>[^1]: I am one</p>
    HTML

    cooked = PrettyText.cook markdown.strip
    expect(cooked).to eq(html.strip)
  end

  it "supports normal footnotes" do
    markdown = <<~MD
      Here is a footnote, [^1] and another. [^test]

      [^1]: I am one

      [^test]: I am one

       test multiline
    MD

    html = <<~HTML
      <p>Here is a footnote, <sup class="footnote-ref"><a href="#fn1" id="fnref1">[1]</a></sup> and another. <sup class="footnote-ref"><a href="#fn2" id="fnref2">[2]</a></sup></p>
      <p>test multiline</p>
      <hr class="footnotes-sep">

      <ol class="footnotes-list">
      <li id="fn1" class="footnote-item"><p>I am one <a href="#fnref1" class="footnote-backref">↩︎</a></p>
      </li>
      <li id="fn2" class="footnote-item"><p>I am one <a href="#fnref2" class="footnote-backref">↩︎</a></p>
      </li>
      </ol>
    HTML

    cooked = PrettyText.cook markdown.strip
    expect(cooked).to eq(html.strip)
  end

  it "applies unique ids to elements after cooking a post" do
    raw = <<~MD
      Here is a footnote, [^1] and another. [^test]

      [^1]: I am one

      [^test]: I am one

       test multiline
    MD

    post = create_post(raw: raw)
    post.reload

    html = <<~HTML
      <p>Here is a footnote, <sup class="footnote-ref"><a href="#footnote-#{post.id}-1" id="footnote-ref-#{post.id}-1">[1]</a></sup> and another. <sup class="footnote-ref"><a href="#footnote-#{post.id}-2" id="footnote-ref-#{post.id}-2">[2]</a></sup></p>
      <p>test multiline</p>
      <hr class="footnotes-sep">

      <ol class="footnotes-list">
      <li id="footnote-#{post.id}-1" class="footnote-item"><p>I am one <a href="#footnote-ref-#{post.id}-1" class="footnote-backref">↩︎</a></p>
      </li>
      <li id="footnote-#{post.id}-2" class="footnote-item"><p>I am one <a href="#footnote-ref-#{post.id}-2" class="footnote-backref">↩︎</a></p>
      </li>
      </ol>
    HTML

    expect(post.cooked.strip).to eq(html.strip)
  end

  it "supports inline footnotes wrapped in <a> elements by ending the elements early" do
    raw = <<~MD
      I have a point, see footnote. <a>^[the point]</a>

      <a>^[footnote]</a>
    MD

    post = create_post(raw: raw)
    post.reload

    html = <<~HTML
      <p>I have a point, see footnote. <a></a><sup class="footnote-ref"><a href="#footnote-#{post.id}-1" id="footnote-ref-#{post.id}-1">[1]</a></sup></p>
      <p><a></a><sup class="footnote-ref"><a href="#footnote-#{post.id}-2" id="footnote-ref-#{post.id}-2">[2]</a></sup></p>
      <hr class="footnotes-sep">

      <ol class="footnotes-list">
      <li id="footnote-#{post.id}-1" class="footnote-item"><p>the point <a href="#footnote-ref-#{post.id}-1" class="footnote-backref">↩︎</a></p>
      </li>
      <li id="footnote-#{post.id}-2" class="footnote-item"><p>footnote <a href="#footnote-ref-#{post.id}-2" class="footnote-backref">↩︎</a></p>
      </li>
      </ol>
    HTML

    expect(post.cooked.strip).to eq(html.strip)
  end
end
