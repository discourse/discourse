require 'rails_helper'
require 'html_normalize'

describe HtmlNormalize do

  def n(html)
    HtmlNormalize.normalize(html)
  end

  it "handles self closing tags" do

    source = <<-HTML
<div>
  <span><img src='testing'>
  boo</span>
</div>
HTML
    expect(n source).to eq(source.strip)
  end

  it "Can handle aside" do

      source = <<~HTML
        <aside class="quote" data-topic="2" data-post="1">
          <div class="title">
          <div class="quote-controls"></div>
          <a href="http://test.localhost/t/this-is-a-test-topic-slight-smile/x/2">This is a test topic <img src="/images/emoji/emoji_one/slight_smile.png?v=5" title="slight_smile" alt="slight_smile" class="emoji"></a></div>
          <blockquote>
          <p>ddd</p>
          </blockquote></aside>
HTML
      expected = <<~HTML
        <aside class="quote" data-post="1" data-topic="2">
          <div class="title">
          <div class="quote-controls"></div>
          <a href="http://test.localhost/t/this-is-a-test-topic-slight-smile/x/2">This is a test topic <img src="/images/emoji/emoji_one/slight_smile.png?v=5" title="slight_smile" alt="slight_smile" class="emoji"></a>
          </div>
          <blockquote>
            <p>ddd</p>
          </blockquote>
        </aside>
HTML

      expect(n expected).to eq(n source)
  end

  it "Can normalize attributes" do

    source = "<a class='a b' name='sam'>b</a>"
    same = "<a name='sam' class='a b' >b</a>"

    expect(n source).to eq(n same)
  end

  it "Can indent divs nicely" do
    source = "<div> <div><div>hello world</div> </div>     </div>"
    expected = <<~HTML
        <div>
          <div>
            <div>
              hello world
            </div>
          </div>
        </div>
HTML

    expect(n source).to eq(expected.strip)
  end
end
