require 'rails_helper'
require 'pretty_text'

describe PrettyText do

  let(:wrapped_image) { "<div class=\"lightbox-wrapper\"><a href=\"//localhost:3000/uploads/default/4399/33691397e78b4d75.png\" class=\"lightbox\" title=\"Screen Shot 2014-04-14 at 9.47.10 PM.png\"><img src=\"//localhost:3000/uploads/default/_optimized/bd9/b20/bbbcd6a0c0_655x500.png\" width=\"655\" height=\"500\"><div class=\"meta\">\n<span class=\"filename\">Screen Shot 2014-04-14 at 9.47.10 PM.png</span><span class=\"informations\">966x737 1.47 MB</span><span class=\"expand\"></span>\n</div></a></div>" }
  let(:wrapped_image_excerpt) {  }

  describe "Cooking" do

    describe "off topic quoting" do
      it "can correctly populate topic title" do
        topic = Fabricate(:topic, title: "this is a test topic :slight_smile:")
        expected = <<HTML
<aside class="quote" data-post="2" data-topic="#{topic.id}"><div class="title">
<div class="quote-controls"></div><a href="http://test.localhost/t/this-is-a-test-topic-slight-smile/#{topic.id}/2">This is a test topic <img src="/images/emoji/emoji_one/slight_smile.png?v=3" title="slight_smile" alt="slight_smile" class="emoji"></a>
</div>
<blockquote><p>ddd</p></blockquote></aside>
HTML
        expect(PrettyText.cook("[quote=\"EvilTrout, post:2, topic:#{topic.id}\"]ddd\n[/quote]", topic_id: 1)).to match_html expected
      end
    end

    describe "with avatar" do
      let(:default_avatar) { "//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/{size}.png" }
      let(:user) { Fabricate(:user) }

      before do
        User.stubs(:default_template).returns(default_avatar)
      end

      it "produces a quote even with new lines in it" do
        expect(PrettyText.cook("[quote=\"#{user.username}, post:123, topic:456, full:true\"]ddd\n[/quote]")).to match_html "<aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">\n<div class=\"quote-controls\"></div>\n<img alt='' width=\"20\" height=\"20\" src=\"//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png\" class=\"avatar\">#{user.username}:</div>\n<blockquote><p>ddd</p></blockquote></aside>"
      end

      it "should produce a quote" do
        expect(PrettyText.cook("[quote=\"#{user.username}, post:123, topic:456, full:true\"]ddd[/quote]")).to match_html "<aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">\n<div class=\"quote-controls\"></div>\n<img alt='' width=\"20\" height=\"20\" src=\"//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png\" class=\"avatar\">#{user.username}:</div>\n<blockquote><p>ddd</p></blockquote></aside>"
      end

      it "trims spaces on quote params" do
        expect(PrettyText.cook("[quote=\"#{user.username}, post:555, topic: 666\"]ddd[/quote]")).to match_html "<aside class=\"quote\" data-post=\"555\" data-topic=\"666\"><div class=\"title\">\n<div class=\"quote-controls\"></div>\n<img alt='' width=\"20\" height=\"20\" src=\"//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png\" class=\"avatar\">#{user.username}:</div>\n<blockquote><p>ddd</p></blockquote></aside>"
      end

    end

    it "should handle 3 mentions in a row" do
      expect(PrettyText.cook('@hello @hello @hello')).to match_html "<p><span class=\"mention\">@hello</span> <span class=\"mention\">@hello</span> <span class=\"mention\">@hello</span></p>"
    end

    it "should handle group mentions with a hyphen and without" do
      expect(PrettyText.cook('@hello @hello-hello')).to match_html "<p><span class=\"mention\">@hello</span> <span class=\"mention\">@hello-hello</span></p>"
    end


    it "should sanitize the html" do
      expect(PrettyText.cook("<script>alert(42)</script>")).to match_html "<p></p>"
    end

    it 'should allow for @mentions to have punctuation' do
      expect(PrettyText.cook("hello @bob's @bob,@bob; @bob\"")).to match_html(
        "<p>hello <span class=\"mention\">@bob</span>'s <span class=\"mention\">@bob</span>,<span class=\"mention\">@bob</span>; <span class=\"mention\">@bob</span>\"</p>"
      )
    end

    # see: https://github.com/sparklemotion/nokogiri/issues/1173
    skip 'allows html entities correctly' do
      expect(PrettyText.cook("&aleph;&pound;&#162;")).to eq("<p>&aleph;&pound;&#162;</p>")
    end

  end

  describe "rel nofollow" do
    before do
      SiteSetting.stubs(:add_rel_nofollow_to_user_content).returns(true)
      SiteSetting.stubs(:exclude_rel_nofollow_domains).returns("foo.com|bar.com")
    end

    it "should inject nofollow in all user provided links" do
      expect(PrettyText.cook('<a href="http://cnn.com">cnn</a>')).to match(/nofollow noopener/)
    end

    it "should not inject nofollow in all local links" do
      expect(PrettyText.cook("<a href='#{Discourse.base_url}/test.html'>cnn</a>") !~ /nofollow/).to eq(true)
    end

    it "should not inject nofollow in all subdomain links" do
      expect(PrettyText.cook("<a href='#{Discourse.base_url.sub('http://', 'http://bla.')}/test.html'>cnn</a>") !~ /nofollow/).to eq(true)
    end

    it "should inject nofollow in all non subdomain links" do
      expect(PrettyText.cook("<a href='#{Discourse.base_url.sub('http://', 'http://bla')}/test.html'>cnn</a>")).to match(/nofollow/)
    end

    it "should not inject nofollow for foo.com" do
      expect(PrettyText.cook("<a href='http://foo.com/test.html'>cnn</a>") !~ /nofollow/).to eq(true)
    end

    it "should inject nofollow for afoo.com" do
      expect(PrettyText.cook("<a href='http://afoo.com/test.html'>cnn</a>")).to match(/nofollow/)
    end

    it "should not inject nofollow for bar.foo.com" do
      expect(PrettyText.cook("<a href='http://bar.foo.com/test.html'>cnn</a>") !~ /nofollow/).to eq(true)
    end

    it "should not inject nofollow if omit_nofollow option is given" do
      expect(PrettyText.cook('<a href="http://cnn.com">cnn</a>', omit_nofollow: true) !~ /nofollow/).to eq(true)
    end
  end

  describe "Excerpt" do

    it "sanitizes attempts to inject invalid attributes" do
      spinner = "<a href=\"http://thedailywtf.com/\" data-bbcode=\"' class='fa fa-spin\">WTF</a>"
      expect(PrettyText.excerpt(spinner, 20)).to match_html spinner

      spinner = %q{<a href="http://thedailywtf.com/" title="' class=&quot;fa fa-spin&quot;&gt;&lt;img src='http://thedailywtf.com/Resources/Images/Primary/logo.gif"></a>}
      expect(PrettyText.excerpt(spinner, 20)).to match_html spinner
    end

    context "images" do

      it "should dump images" do
        expect(PrettyText.excerpt("<img src='http://cnn.com/a.gif'>",100)).to eq("[image]")
      end

      context 'alt tags' do
        it "should keep alt tags" do
          expect(PrettyText.excerpt("<img src='http://cnn.com/a.gif' alt='car' title='my big car'>", 100)).to eq("[car]")
        end

        describe 'when alt tag is empty' do
          it "should not keep alt tags" do
            expect(PrettyText.excerpt("<img src='http://cnn.com/a.gif' alt>", 100)).to eq("[#{I18n.t('excerpt_image')}]")
          end
        end
      end

      context 'title tags' do
        it "should keep title tags" do
          expect(PrettyText.excerpt("<img src='http://cnn.com/a.gif' title='car'>", 100)).to eq("[car]")
        end

        describe 'when title tag is empty' do
          it "should not keep title tags" do
            expect(PrettyText.excerpt("<img src='http://cnn.com/a.gif' title>", 100)).to eq("[#{I18n.t('excerpt_image')}]")
          end
        end
      end

      it "should convert images to markdown if the option is set" do
        expect(PrettyText.excerpt("<img src='http://cnn.com/a.gif' title='car'>", 100, markdown_images: true)).to eq("![car](http://cnn.com/a.gif)")
      end

      it "should keep spoilers" do
        expect(PrettyText.excerpt("<div class='spoiler'><img src='http://cnn.com/a.gif'></div>", 100)).to match_html "<span class='spoiler'>[image]</span>"
        expect(PrettyText.excerpt("<span class='spoiler'>spoiler</div>", 100)).to match_html "<span class='spoiler'>spoiler</span>"
      end

      it "should remove meta informations" do
        expect(PrettyText.excerpt(wrapped_image, 100)).to match_html "<a href='//localhost:3000/uploads/default/4399/33691397e78b4d75.png' class='lightbox' title='Screen Shot 2014-04-14 at 9.47.10 PM.png'>[image]</a>"
      end
    end

    it "should have an option to strip links" do
      expect(PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>",100, strip_links: true)).to eq("cnn")
    end

    it "should preserve links" do
      expect(PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>",100)).to match_html "<a href='http://cnn.com'>cnn</a>"
    end

    it "should deal with special keys properly" do
      expect(PrettyText.excerpt("<pre><b></pre>",100)).to eq("")
    end

    it "should truncate stuff properly" do
      expect(PrettyText.excerpt("hello world",5)).to eq("hello&hellip;")
      expect(PrettyText.excerpt("<p>hello</p><p>world</p>",6)).to eq("hello w&hellip;")
    end

    it "should insert a space between to Ps" do
      expect(PrettyText.excerpt("<p>a</p><p>b</p>",5)).to eq("a b")
    end

    it "should strip quotes" do
      expect(PrettyText.excerpt("<aside class='quote'><p>a</p><p>b</p></aside>boom",5)).to eq("boom")
    end

    it "should not count the surrounds of a link" do
      expect(PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>",3)).to match_html "<a href='http://cnn.com'>cnn</a>"
    end

    it "uses an ellipsis instead of html entities if provided with the option" do
      expect(PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>", 2, text_entities: true)).to match_html "<a href='http://cnn.com'>cn...</a>"
    end

    it "should truncate links" do
      expect(PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>",2)).to match_html "<a href='http://cnn.com'>cn&hellip;</a>"
    end

    it "doesn't extract empty quotes as links" do
      expect(PrettyText.extract_links("<aside class='quote'>not a linked quote</aside>\n").to_a).to be_empty
    end

    it "doesn't extract links from elided parts" do
      expect(PrettyText.extract_links("<details class='elided'><a href='http://cnn.com'>cnn</a></details>\n").to_a).to be_empty
    end

    def extract_urls(text)
      PrettyText.extract_links(text).map(&:url).to_a
    end

    it "should be able to extract links" do
      expect(extract_urls("<a href='http://cnn.com'>http://bla.com</a>")).to eq(["http://cnn.com"])
    end

    it "should extract links to topics" do
      expect(extract_urls("<aside class=\"quote\" data-topic=\"321\">aside</aside>")).to eq(["/t/topic/321"])
    end

    it "should lazyYT videos" do
      expect(extract_urls("<div class=\"lazyYT\" data-youtube-id=\"yXEuEUQIP3Q\" data-youtube-title=\"Mister Rogers defending PBS to the US Senate\" data-width=\"480\" data-height=\"270\" data-parameters=\"feature=oembed&amp;wmode=opaque\"></div>")).to eq(["https://www.youtube.com/watch?v=yXEuEUQIP3Q"])
    end

    it "should extract links to posts" do
      expect(extract_urls("<aside class=\"quote\" data-topic=\"1234\" data-post=\"4567\">aside</aside>")).to eq(["/t/topic/1234/4567"])
    end

    it "should not extract links to anchors" do
      expect(extract_urls("<a href='#tos'>TOS</a>")).to eq([])
    end

    it "should not extract links inside quotes" do
      links = PrettyText.extract_links("
        <a href='http://body_only.com'>http://useless1.com</a>
        <aside class=\"quote\" data-topic=\"1234\">
          <a href='http://body_and_quote.com'>http://useless3.com</a>
          <a href='http://quote_only.com'>http://useless4.com</a>
        </aside>
        <a href='http://body_and_quote.com'>http://useless2.com</a>
        ")

      expect(links.map { |l| [l.url, l.is_quote] }.sort).to eq([
        ["http://body_only.com", false],
        ["http://body_and_quote.com", false],
        ["/t/topic/1234", true],
      ].sort)
    end

    it "should not preserve tags in code blocks" do
      expect(PrettyText.excerpt("<pre><code class='handlebars'>&lt;h3&gt;Hours&lt;/h3&gt;</code></pre>",100)).to eq("&lt;h3&gt;Hours&lt;/h3&gt;")
    end

    it "should handle nil" do
      expect(PrettyText.excerpt(nil,100)).to eq('')
    end

    it "handles span excerpt at the beginning of a post" do
      expect(PrettyText.excerpt("<span class='excerpt'>hi</span> test",100)).to eq('hi')
      post = Fabricate(:post, raw: "<span class='excerpt'>hi</span> test")
      expect(post.excerpt).to eq("hi")
    end

    it "ignores max excerpt length if a span excerpt is specified" do
      two_hundred = "123456789 " * 20 + "."
      text =  two_hundred + "<span class='excerpt'>#{two_hundred}</span>" + two_hundred
      expect(PrettyText.excerpt(text, 100)).to eq(two_hundred)
      post = Fabricate(:post, raw: text)
      expect(post.excerpt).to eq(two_hundred)
    end

    it "unescapes html entities when we want text entities" do
      expect(PrettyText.excerpt("&#39;", 500, text_entities: true)).to eq("'")
    end

    it "should have an option to preserve emoji images" do
      emoji_image = "<img src='/images/emoji/emoji_one/heart.png?v=1' title=':heart:' class='emoji' alt='heart'>"
      expect(PrettyText.excerpt(emoji_image, 100, { keep_emoji_images: true })).to match_html(emoji_image)
    end

    it "should have an option to remap emoji to code points" do
      emoji_image = "I <img src='/images/emoji/emoji_one/heart.png?v=1' title=':heart:' class='emoji' alt=':heart:'> you <img src='/images/emoji/emoji_one/heart.png?v=1' title=':unknown:' class='emoji' alt=':unknown:'> "
      expect(PrettyText.excerpt(emoji_image, 100, { remap_emoji: true })).to match_html("I ❤  you :unknown:")
    end

    it "should have an option to preserve emoji codes" do
      emoji_code = "<img src='/images/emoji/emoji_one/heart.png?v=1' title=':heart:' class='emoji' alt=':heart:'>"
      expect(PrettyText.excerpt(emoji_code, 100)).to eq(":heart:")
    end

    context 'option ot preserve onebox source' do
      it "should return the right excerpt" do
        onebox = "<aside class=\"onebox whitelistedgeneric\">\n  <header class=\"source\">\n    <a href=\"https://meta.discourse.org/t/infrequent-translation-updates-in-stable-branch/31213/9\">meta.discourse.org</a>\n  </header>\n  <article class=\"onebox-body\">\n    <img src=\"https://cdn-enterprise.discourse.org/meta/user_avatar/meta.discourse.org/gerhard/200/70381_1.png\" width=\"\" height=\"\" class=\"thumbnail\">\n\n<h3><a href=\"https://meta.discourse.org/t/infrequent-translation-updates-in-stable-branch/31213/9\">Infrequent translation updates in stable branch</a></h3>\n\n<p>Well, there's an Italian translation for \"New Topic\" in beta, it's been there since November 2014 and it works here on meta.     Do you have any plugins installed? Try disabling them. I'm quite confident that it's either a plugin or a site...</p>\n\n  </article>\n  <div class=\"onebox-metadata\">\n    \n    \n  </div>\n  <div style=\"clear: both\"></div>\n</aside>\n\n\n"
        expected = "<a href=\"https://meta.discourse.org/t/infrequent-translation-updates-in-stable-branch/31213/9\">meta.discourse.org</a>"

        expect(PrettyText.excerpt(onebox, 100, keep_onebox_source: true))
          .to eq(expected)

        expect(PrettyText.excerpt("#{onebox}\n  \n \n \n\n\n #{onebox}", 100, keep_onebox_source: true))
          .to eq("#{expected}\n\n#{expected}")
      end

      it 'should continue to strip quotes' do
        expect(PrettyText.excerpt(
          "<aside class='quote'><p>a</p><p>b</p></aside>boom", 100, keep_onebox_source: true
        )).to eq("boom")
      end
    end

  end

  describe "strip links" do
    it "returns blank for blank input" do
      expect(PrettyText.strip_links("")).to be_blank
    end

    it "does nothing to a string without links" do
      expect(PrettyText.strip_links("I'm the <b>batman</b>")).to eq("I'm the <b>batman</b>")
    end

    it "strips links but leaves the text content" do
      expect(PrettyText.strip_links("I'm the linked <a href='http://en.wikipedia.org/wiki/Batman'>batman</a>")).to eq("I'm the linked batman")
    end

    it "escapes the text content" do
      expect(PrettyText.strip_links("I'm the linked <a href='http://en.wikipedia.org/wiki/Batman'>&lt;batman&gt;</a>")).to eq("I'm the linked &lt;batman&gt;")
    end
  end

  describe "strip_image_wrapping" do
    def strip_image_wrapping(html)
      doc = Nokogiri::HTML.fragment(html)
      described_class.strip_image_wrapping(doc)
      doc.to_html
    end

    it "doesn't change HTML when there's no wrapped image" do
      html = "<img src=\"wat.png\">"
      expect(strip_image_wrapping(html)).to eq(html)
    end

    it "strips the metadata" do
      expect(strip_image_wrapping(wrapped_image)).to match_html "<div class=\"lightbox-wrapper\"><a href=\"//localhost:3000/uploads/default/4399/33691397e78b4d75.png\" class=\"lightbox\" title=\"Screen Shot 2014-04-14 at 9.47.10 PM.png\"><img src=\"//localhost:3000/uploads/default/_optimized/bd9/b20/bbbcd6a0c0_655x500.png\" width=\"655\" height=\"500\"></a></div>"
    end
  end

  describe 'format_for_email' do
    let(:base_url) { "http://baseurl.net" }
    let(:post) { Fabricate(:post) }

    before do
      Discourse.stubs(:base_url).returns(base_url)
    end

    it 'does not crash' do
      PrettyText.format_for_email('<a href="mailto:michael.brown@discourse.org?subject=Your%20post%20at%20http://try.discourse.org/t/discussion-happens-so-much/127/1000?u=supermathie">test</a>', post)
    end

    it "adds base url to relative links" do
      html = "<p><a class=\"mention\" href=\"/u/wiseguy\">@wiseguy</a>, <a class=\"mention\" href=\"/u/trollol\">@trollol</a> what do you guys think? </p>"
      output = described_class.format_for_email(html, post)
      expect(output).to eq("<p><a class=\"mention\" href=\"#{base_url}/u/wiseguy\">@wiseguy</a>, <a class=\"mention\" href=\"#{base_url}/u/trollol\">@trollol</a> what do you guys think? </p>")
    end

    it "doesn't change external absolute links" do
      html = "<p>Check out <a href=\"http://mywebsite.com/users/boss\">this guy</a>.</p>"
      expect(described_class.format_for_email(html, post)).to eq(html)
    end

    it "doesn't change internal absolute links" do
      html = "<p>Check out <a href=\"#{base_url}/users/boss\">this guy</a>.</p>"
      expect(described_class.format_for_email(html, post)).to eq(html)
    end

    it "can tolerate invalid URLs" do
      html = "<p>Check out <a href=\"not a real url\">this guy</a>.</p>"
      expect { described_class.format_for_email(html, post) }.to_not raise_error
    end
  end

  it 'can escape *' do
    expect(PrettyText.cook("***a***a")).to match_html("<p><strong><em>a</em></strong>a</p>")
    expect(PrettyText.cook("***\\****a")).to match_html("<p><strong><em>*</em></strong>a</p>")
  end

  it 'can include code class correctly' do
    expect(PrettyText.cook("```cpp\ncpp\n```")).to match_html("<p></p><pre><code class='lang-cpp'>cpp</code></pre>")
  end

  it 'indents code correctly' do
    code = "X\n```\n\n    #\n    x\n```"
    cooked = PrettyText.cook(code)
    expect(cooked).to match_html("<p>X<br></p>\n\n<p></p><pre><code class=\"lang-auto\">    #\n    x</code></pre>")
  end

  it 'can substitute s3 cdn correctly' do
    SiteSetting.enable_s3_uploads = true
    SiteSetting.s3_access_key_id = "XXX"
    SiteSetting.s3_secret_access_key = "XXX"
    SiteSetting.s3_upload_bucket = "test"
    SiteSetting.s3_cdn_url = "https://awesome.cdn"

    # add extra img tag to ensure it does not blow up
    raw = <<HTML
  <img>
  <img src='https:#{Discourse.store.absolute_base_url}/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg'>
  <img src='http:#{Discourse.store.absolute_base_url}/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg'>
  <img src='#{Discourse.store.absolute_base_url}/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg'>

HTML

    cooked = <<HTML
<p>  <img><br>  <img src="https://awesome.cdn/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg"><br>  <img src="https://awesome.cdn/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg"><br>  <img src="https://awesome.cdn/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg"></p>
HTML

    expect(PrettyText.cook(raw)).to match_html(cooked)
  end

  describe 'tables' do
    it 'allows table html' do
      SiteSetting.allow_html_tables = true
      table = "<table class='fa-spin'><thead><tr>\n<th class='fa-spin'>test</th></tr></thead><tbody><tr><td>a</td></tr></tbody></table>"
      match = "<table class=\"md-table\"><thead><tr> <th>test</th> </tr></thead><tbody><tr><td>a</td></tr></tbody></table>"
      expect(PrettyText.cook(table)).to match_html(match)
    end

    it 'allows no tables when not enabled' do
      SiteSetting.allow_html_tables = false
      table = "<table><thead><tr><th>test</th></tr></thead><tbody><tr><td>a</td></tr></tbody></table>"
      expect(PrettyText.cook(table)).to match_html("")
    end
  end

  describe "emoji" do
    it "replaces unicode emoji with our emoji sets if emoji is enabled" do
      expect(PrettyText.cook("💣")).to match(/\:bomb\:/)
    end

    it "doesn't replace emoji in inline code blocks with our emoji sets if emoji is enabled" do
      expect(PrettyText.cook("`💣`")).not_to match(/\:bomb\:/)
    end

    it "doesn't replace emoji in code blocks with our emoji sets if emoji is enabled" do
      expect(PrettyText.cook("```\n💣`\n```\n")).not_to match(/\:bomb\:/)
    end

    it "replaces some glyphs that are not in the emoji range" do
      expect(PrettyText.cook("☺")).to match(/\:slight_smile\:/)
    end

    it "doesn't replace unicode emoji if emoji is disabled" do
      SiteSetting.enable_emoji = false
      expect(PrettyText.cook("💣")).not_to match(/\:bomb\:/)
    end
  end

  describe "tag and category links" do
    it "produces tag links" do
      Fabricate(:topic, {tags: [Fabricate(:tag, name: 'known')]})
      expect(PrettyText.cook(" #unknown::tag #known::tag")).to match_html("<p> <span class=\"hashtag\">#unknown::tag</span> <a class=\"hashtag\" href=\"http://test.localhost/tags/known\">#<span>known</span></a></p>")
    end

    # TODO does it make sense to generate hashtags for tags that are missing in action?
  end

  describe "custom emoji" do
    it "replaces the custom emoji" do
      CustomEmoji.create!(name: 'trout', upload: Fabricate(:upload))
      Emoji.clear_cache

      expect(PrettyText.cook("hello :trout:")).to match(/<img src[^>]+trout[^>]+>/)
    end
  end

  describe "censored_pattern site setting" do
    it "can be cleared if it causes cooking to timeout" do
      SiteSetting.censored_pattern = "evilregex"
      described_class.stubs(:markdown).raises(MiniRacer::ScriptTerminatedError)
      PrettyText.cook("Protect against it plz.") rescue nil
      expect(SiteSetting.censored_pattern).to be_blank
    end
  end

end
