require 'rails_helper'
require 'pretty_text'

describe PrettyText do

  before do
    SiteSetting.enable_markdown_typographer = false
  end

  def n(html)
    html.strip
  end

  def cook(*args)
    PrettyText.cook(*args)
  end

  let(:wrapped_image) { "<div class=\"lightbox-wrapper\"><a href=\"//localhost:3000/uploads/default/4399/33691397e78b4d75.png\" class=\"lightbox\" title=\"Screen Shot 2014-04-14 at 9.47.10 PM.png\"><img src=\"//localhost:3000/uploads/default/_optimized/bd9/b20/bbbcd6a0c0_655x500.png\" width=\"655\" height=\"500\"><div class=\"meta\">\n<span class=\"filename\">Screen Shot 2014-04-14 at 9.47.10 PM.png</span><span class=\"informations\">966x737 1.47 MB</span><span class=\"expand\"></span>\n</div></a></div>" }
  let(:wrapped_image_excerpt) {}

  describe "Quoting" do

    describe "with avatar" do
      let(:default_avatar) { "//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/{size}.png" }
      let(:user) { Fabricate(:user) }

      before do
        User.stubs(:default_template).returns(default_avatar)
      end

      it "do off topic quoting with emoji unescape" do

        topic = Fabricate(:topic, title: "this is a test topic :slight_smile:")
        expected = <<~HTML
          <aside class="quote no-group" data-post="2" data-topic="#{topic.id}">
          <div class="title">
          <div class="quote-controls"></div>
          <a href="http://test.localhost/t/this-is-a-test-topic/#{topic.id}/2">This is a test topic <img src="/images/emoji/twitter/slight_smile.png?v=5" title="slight_smile" alt="slight_smile" class="emoji"></a>
          </div>
          <blockquote>
          <p>ddd</p>
          </blockquote>
          </aside>
        HTML

        expect(cook("[quote=\"EvilTrout, post:2, topic:#{topic.id}\"]\nddd\n[/quote]", topic_id: 1)).to eq(n(expected))
      end

      it "indifferent about missing quotations" do
        md = <<~MD
          [quote=#{user.username}, post:123, topic:456, full:true]

          ddd

          [/quote]
        MD
        html = <<~HTML
          <aside class="quote no-group" data-post="123" data-topic="456" data-full="true">
          <div class="title">
          <div class="quote-controls"></div>
          <img alt width="20" height="20" src="//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png" class="avatar"> #{user.username}:</div>
          <blockquote>
          <p>ddd</p>
          </blockquote>
          </aside>
        HTML

        expect(PrettyText.cook(md)).to eq(html.strip)
      end

      it "indifferent about curlies and no curlies" do
        md = <<~MD
          [quote=“#{user.username}, post:123, topic:456, full:true”]

          ddd

          [/quote]
        MD
        html = <<~HTML
          <aside class="quote no-group" data-post="123" data-topic="456" data-full="true">
          <div class="title">
          <div class="quote-controls"></div>
          <img alt width="20" height="20" src="//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png" class="avatar"> #{user.username}:</div>
          <blockquote>
          <p>ddd</p>
          </blockquote>
          </aside>
        HTML

        expect(PrettyText.cook(md)).to eq(html.strip)
      end

      it "trims spaces on quote params" do
        md = <<~MD
          [quote="#{user.username}, post:555, topic: 666"]
          ddd
          [/quote]
        MD

        html = <<~HTML
          <aside class="quote no-group" data-post="555" data-topic="666">
          <div class="title">
          <div class="quote-controls"></div>
          <img alt width="20" height="20" src="//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png" class="avatar"> #{user.username}:</div>
          <blockquote>
          <p>ddd</p>
          </blockquote>
          </aside>
        HTML

        expect(PrettyText.cook(md)).to eq(html.strip)
      end
    end

    describe "with primary user group" do
      let(:default_avatar) { "//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/{size}.png" }
      let(:group) { Fabricate(:group) }
      let!(:user) { Fabricate(:user, primary_group: group) }

      before do
        User.stubs(:default_template).returns(default_avatar)
      end

      it "adds primary group class to referenced users quote" do

        topic = Fabricate(:topic, title: "this is a test topic")
        expected = <<~HTML
          <aside class="quote group-#{group.name}" data-post="2" data-topic="#{topic.id}">
          <div class="title">
          <div class="quote-controls"></div>
          <img alt width="20" height="20" src="//test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png" class="avatar"><a href="http://test.localhost/t/this-is-a-test-topic/#{topic.id}/2">This is a test topic</a>
          </div>
          <blockquote>
          <p>ddd</p>
          </blockquote>
          </aside>
        HTML

        expect(cook("[quote=\"#{user.username}, post:2, topic:#{topic.id}\"]\nddd\n[/quote]", topic_id: 1)).to eq(n(expected))
      end
    end

    it "can handle inline block bbcode" do
      cooked = PrettyText.cook("[quote]te **s** t[/quote]")

      html = <<~HTML
        <aside class="quote no-group">
        <blockquote>
        <p>te <strong>s</strong> t</p>
        </blockquote>
        </aside>
      HTML

      expect(cooked).to eq(html.strip)
    end

    it "handles bbcode edge cases" do
      expect(PrettyText.cook "[constructor]\ntest").to eq("<p>[constructor]<br>\ntest</p>")
    end

    it "can handle quote edge cases" do
      expect(PrettyText.cook("[quote]abc\ntest\n[/quote]")).not_to include('aside')
      expect(PrettyText.cook("[quote]  \ntest\n[/quote]  ")).to include('aside')
      expect(PrettyText.cook("a\n[quote]\ntest\n[/quote]\n\n\na")).to include('aside')
      expect(PrettyText.cook("- a\n[quote]\ntest\n[/quote]\n\n\na")).to include('aside')
      expect(PrettyText.cook("[quote]\ntest")).not_to include('aside')
      expect(PrettyText.cook("[quote]\ntest\n[/quote]z")).not_to include('aside')

      nested = <<~QUOTE
        [quote]
        a
        [quote]
        b
        [/quote]
        c
        [/quote]
      QUOTE

      cooked = PrettyText.cook(nested)
      expect(cooked.scan('aside').length).to eq(4)
      expect(cooked.scan('quote]').length).to eq(0)
    end

    describe "with letter avatar" do
      let(:user) { Fabricate(:user) }

      context "subfolder" do
        before do
          GlobalSetting.stubs(:relative_url_root).returns("/forum")
          Discourse.stubs(:base_uri).returns("/forum")
        end

        it "should have correct avatar url" do
          md = <<~MD
            [quote="#{user.username}, post:123, topic:456, full:true"]
            ddd
            [/quote]
          MD
          expect(PrettyText.cook(md)).to include("/forum/letter_avatar_proxy")
        end
      end
    end
  end

  describe "Mentions" do

    it "can handle mentions after abbr" do
      expect(PrettyText.cook("test <abbr>test</abbr>\n\n@bob")).to eq("<p>test <abbr>test</abbr></p>\n<p><span class=\"mention\">@bob</span></p>")
    end

    it "should handle 3 mentions in a row" do
      expect(PrettyText.cook('@hello @hello @hello')).to match_html "<p><span class=\"mention\">@hello</span> <span class=\"mention\">@hello</span> <span class=\"mention\">@hello</span></p>"
    end

    it "can handle mention edge cases" do
      expect(PrettyText.cook("hi\n@s")).to eq("<p>hi<br>\n<span class=\"mention\">@s</span></p>")
      expect(PrettyText.cook("hi\n@ss")).to eq("<p>hi<br>\n<span class=\"mention\">@ss</span></p>")
      expect(PrettyText.cook("hi\n@s.")).to eq("<p>hi<br>\n<span class=\"mention\">@s</span>.</p>")
      expect(PrettyText.cook("hi\n@s.s")).to eq("<p>hi<br>\n<span class=\"mention\">@s.s</span></p>")
      expect(PrettyText.cook("hi\n@.s.s")).to eq("<p>hi<br>\n@.s.s</p>")
    end

    it "can handle mention with hyperlinks" do
      Fabricate(:user, username: "sam")
      expect(PrettyText.cook("hi @sam! hi")).to match_html '<p>hi <a class="mention" href="/u/sam">@sam</a>! hi</p>'
      expect(PrettyText.cook("hi\n@sam.")).to eq("<p>hi<br>\n<a class=\"mention\" href=\"/u/sam\">@sam</a>.</p>")
    end

    it "can handle mentions inside a hyperlink" do
      expect(PrettyText.cook("<a> @inner</a> ")).to match_html '<p><a> @inner</a></p>'
    end

    it "can handle mentions inside a hyperlink" do
      expect(PrettyText.cook("[link @inner](http://site.com)")).to match_html '<p><a href="http://site.com" rel="nofollow noopener">link @inner</a></p>'
    end

    it "can handle a list of mentions" do
      expect(PrettyText.cook("@a,@b")).to match_html('<p><span class="mention">@a</span>,<span class="mention">@b</span></p>')
    end

    it "should handle group mentions with a hyphen and without" do
      expect(PrettyText.cook('@hello @hello-hello')).to match_html "<p><span class=\"mention\">@hello</span> <span class=\"mention\">@hello-hello</span></p>"
    end

    it 'should allow for @mentions to have punctuation' do
      expect(PrettyText.cook("hello @bob's @bob,@bob; @bob\"")).to match_html(
        "<p>hello <span class=\"mention\">@bob</span>'s <span class=\"mention\">@bob</span>,<span class=\"mention\">@bob</span>; <span class=\"mention\">@bob</span>\"</p>"
      )
    end

    it 'should not treat a medium link as a mention' do
      expect(PrettyText.cook(". http://test/@sam")).not_to include('mention')
    end

  end

  describe "code fences" do
    it 'indents code correctly' do
      code = <<~MD
         X
         ```
              #
              x
         ```
      MD
      cooked = PrettyText.cook(code)

      html = <<~HTML
        <p>X</p>
        <pre><code class="lang-auto">     #
             x
        </code></pre>
      HTML

      expect(cooked).to eq(html.strip)
    end

    it "doesn't replace emoji in code blocks with our emoji sets if emoji is enabled" do
      expect(PrettyText.cook("```\n💣`\n```\n")).not_to match(/\:bomb\:/)
    end

    it 'can include code class correctly' do
      # keep in mind spaces should be trimmed per spec
      expect(PrettyText.cook("```   ruby the mooby\n`````")).to eq('<pre><code class="lang-ruby"></code></pre>')
      expect(PrettyText.cook("```cpp\ncpp\n```")).to match_html("<pre><code class='lang-cpp'>cpp\n</code></pre>")
      expect(PrettyText.cook("```\ncpp\n```")).to match_html("<pre><code class='lang-auto'>cpp\n</code></pre>")
      expect(PrettyText.cook("```text\ncpp\n```")).to match_html("<pre><code class='lang-nohighlight'>cpp\n</code></pre>")

    end

    it 'indents code correctly' do
      code = "X\n```\n\n    #\n    x\n```"
      cooked = PrettyText.cook(code)
      expect(cooked).to match_html("<p>X</p>\n<pre><code class=\"lang-auto\">\n    #\n    x\n</code></pre>")
    end

    it 'does censor code fences' do
      begin
        ['apple', 'banana'].each { |w| Fabricate(:watched_word, word: w, action: WatchedWord.actions[:censor]) }
        expect(PrettyText.cook("# banana")).not_to include('banana')
      ensure
        $redis.flushall
      end
    end
  end

  describe "rel nofollow" do
    before do
      SiteSetting.add_rel_nofollow_to_user_content = true
      SiteSetting.exclude_rel_nofollow_domains = "foo.com|bar.com"
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
        expect(PrettyText.excerpt("<img src='http://cnn.com/a.gif'>", 100)).to eq("[image]")
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

      it "should keep details if too long" do
        expect(PrettyText.excerpt("<details><summary>expand</summary><p>hello</p></details>", 6)).to match_html "<details class='disabled'><summary>expand</summary></details>"
      end

      it "doesn't disable details if short enough" do
        expect(PrettyText.excerpt("<details><summary>expand</summary><p>hello</p></details>", 60)).to match_html "<details><summary>expand</summary>hello</details>"
      end

      it "should remove meta informations" do
        expect(PrettyText.excerpt(wrapped_image, 100)).to match_html "<a href='//localhost:3000/uploads/default/4399/33691397e78b4d75.png' class='lightbox' title='Screen Shot 2014-04-14 at 9.47.10 PM.png'>[image]</a>"
      end

      it "should strip images when option is set" do
        expect(PrettyText.excerpt("<img src='http://cnn.com/a.gif'>", 100, strip_images: true)).to be_blank
        expect(PrettyText.excerpt("<img src='http://cnn.com/a.gif'> Hello world!", 100, strip_images: true)).to eq("Hello world!")
      end

      it "should strip images, but keep emojis when option is set" do
        emoji_image = "<img src='/images/emoji/twitter/heart.png?v=1' title=':heart:' class='emoji' alt='heart'>"
        html = "<img src='http://cnn.com/a.gif'> Hello world #{emoji_image}"

        expect(PrettyText.excerpt(html, 100, strip_images: true)).to eq("Hello world heart")
        expect(PrettyText.excerpt(html, 100, strip_images: true, keep_emoji_images: true)).to match_html("Hello world #{emoji_image}")
      end
    end

    it "should have an option to strip links" do
      expect(PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>", 100, strip_links: true)).to eq("cnn")
    end

    it "should preserve links" do
      expect(PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>", 100)).to match_html "<a href='http://cnn.com'>cnn</a>"
    end

    it "should deal with special keys properly" do
      expect(PrettyText.excerpt("<pre><b></pre>", 100)).to eq("")
    end

    it "should truncate stuff properly" do
      expect(PrettyText.excerpt("hello world", 5)).to eq("hello&hellip;")
      expect(PrettyText.excerpt("<p>hello</p><p>world</p>", 6)).to eq("hello w&hellip;")
    end

    it "should insert a space between to Ps" do
      expect(PrettyText.excerpt("<p>a</p><p>b</p>", 5)).to eq("a b")
    end

    it "should strip quotes" do
      expect(PrettyText.excerpt("<aside class='quote'><p>a</p><p>b</p></aside>boom", 5)).to eq("boom")
    end

    it "should not count the surrounds of a link" do
      expect(PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>", 3)).to match_html "<a href='http://cnn.com'>cnn</a>"
    end

    it "uses an ellipsis instead of html entities if provided with the option" do
      expect(PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>", 2, text_entities: true)).to match_html "<a href='http://cnn.com'>cn...</a>"
    end

    it "should truncate links" do
      expect(PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>", 2)).to match_html "<a href='http://cnn.com'>cn&hellip;</a>"
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
      expect(PrettyText.excerpt("<pre><code class='handlebars'>&lt;h3&gt;Hours&lt;/h3&gt;</code></pre>", 100)).to eq("&lt;h3&gt;Hours&lt;/h3&gt;")
    end

    it "should handle nil" do
      expect(PrettyText.excerpt(nil, 100)).to eq('')
    end

    it "handles span excerpt at the beginning of a post" do
      expect(PrettyText.excerpt("<span class='excerpt'>hi</span> test", 100)).to eq('hi')
      post = Fabricate(:post, raw: "<span class='excerpt'>hi</span> test")
      expect(post.excerpt).to eq("hi")
    end

    it "ignores max excerpt length if a span excerpt is specified" do
      two_hundred = "123456789 " * 20 + "."
      text = two_hundred + "<span class='excerpt'>#{two_hundred}</span>" + two_hundred
      expect(PrettyText.excerpt(text, 100)).to eq(two_hundred)
      post = Fabricate(:post, raw: text)
      expect(post.excerpt).to eq(two_hundred)
    end

    it "unescapes html entities when we want text entities" do
      expect(PrettyText.excerpt("&#39;", 500, text_entities: true)).to eq("'")
    end

    it "should have an option to preserve emoji images" do
      emoji_image = "<img src='/images/emoji/twitter/heart.png?v=1' title=':heart:' class='emoji' alt='heart'>"
      expect(PrettyText.excerpt(emoji_image, 100, keep_emoji_images: true)).to match_html(emoji_image)
    end

    it "should have an option to remap emoji to code points" do
      emoji_image = "I <img src='/images/emoji/twitter/heart.png?v=1' title=':heart:' class='emoji' alt=':heart:'> you <img src='/images/emoji/twitter/heart.png?v=1' title=':unknown:' class='emoji' alt=':unknown:'> "
      expect(PrettyText.excerpt(emoji_image, 100, remap_emoji: true)).to match_html("I ❤  you :unknown:")
    end

    it "should have an option to preserve emoji codes" do
      emoji_code = "<img src='/images/emoji/twitter/heart.png?v=1' title=':heart:' class='emoji' alt=':heart:'>"
      expect(PrettyText.excerpt(emoji_code, 100)).to eq(":heart:")
    end

    context 'option to preserve onebox source' do
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

    it "doesn't change mailto" do
      html = "<p>Contact me at <a href=\"mailto:username@me.com\">this address</a>.</p>"
      expect(PrettyText.format_for_email(html, post)).to eq(html)
    end
  end

  it 'Is smart about linebreaks and IMG tags' do
    raw = <<~MD
    a <img>
    <img>

    <img>
    <img>

    <img>
    a

    <img>
    - li

    <img>
    ```
    test
    ```

    ```
    test
    ```
    MD

    html = <<~HTML
      <p>a <img><br>
      <img></p>
      <p><img><br>
      <img></p>
      <p><img></p>
      <p>a</p>
      <p><img></p>
      <ul>
      <li>li</li>
      </ul>
      <p><img></p>
      <pre><code class="lang-auto">test
      </code></pre>
      <pre><code class="lang-auto">test
      </code></pre>
    HTML

    expect(PrettyText.cook(raw)).to eq(html.strip)
  end

  describe 's3_cdn' do

    def test_s3_cdn
      # add extra img tag to ensure it does not blow up
      raw = <<~HTML
        <img>
        <img src='https:#{Discourse.store.absolute_base_url}/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg'>
        <img src='http:#{Discourse.store.absolute_base_url}/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg'>
        <img src='#{Discourse.store.absolute_base_url}/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg'>
      HTML

      html = <<~HTML
        <p><img><br>
        <img src="https://awesome.cdn/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg"><br>
        <img src="https://awesome.cdn/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg"><br>
        <img src="https://awesome.cdn/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg"></p>
      HTML

      expect(PrettyText.cook(raw)).to eq(html.strip)
    end

    before do
      GlobalSetting.reset_s3_cache!
    end

    after do
      GlobalSetting.reset_s3_cache!
    end

    it 'can substitute s3 cdn when added via global setting' do

      global_setting :s3_access_key_id, 'XXX'
      global_setting :s3_secret_access_key, 'XXX'
      global_setting :s3_bucket, 'XXX'
      global_setting :s3_region, 'XXX'
      global_setting :s3_cdn_url, 'https://awesome.cdn'

      test_s3_cdn
    end

    it 'can substitute s3 cdn correctly' do
      SiteSetting.s3_access_key_id = "XXX"
      SiteSetting.s3_secret_access_key = "XXX"
      SiteSetting.s3_upload_bucket = "test"
      SiteSetting.s3_cdn_url = "https://awesome.cdn"

      SiteSetting.enable_s3_uploads = true

      test_s3_cdn
    end

    def test_s3_with_subfolder_cdn
      raw = <<~RAW
        <img src='https:#{Discourse.store.absolute_base_url}/subfolder/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg'>
      RAW

      html = <<~HTML
        <p><img src="https://awesome.cdn/subfolder/original/9/9/99c9384b8b6d87f8509f8395571bc7512ca3cad1.jpg"></p>
      HTML

      expect(PrettyText.cook(raw)).to eq(html.strip)
    end

    it 'can substitute s3 with subfolder cdn when added via global setting' do

      global_setting :s3_access_key_id, 'XXX'
      global_setting :s3_secret_access_key, 'XXX'
      global_setting :s3_bucket, 'XXX/subfolder'
      global_setting :s3_region, 'XXX'
      global_setting :s3_cdn_url, 'https://awesome.cdn/subfolder'

      test_s3_with_subfolder_cdn
    end
  end

  describe "emoji" do
    it "replaces unicode emoji with our emoji sets if emoji is enabled" do
      expect(PrettyText.cook("💣")).to match(/\:bomb\:/)
    end

    it "doesn't replace emoji in inline code blocks with our emoji sets if emoji is enabled" do
      expect(PrettyText.cook("`💣`")).not_to match(/\:bomb\:/)
    end

    it "replaces some glyphs that are not in the emoji range" do
      expect(PrettyText.cook("☺")).to match(/\:slight_smile\:/)
    end

    it "doesn't replace unicode emoji if emoji is disabled" do
      SiteSetting.enable_emoji = false
      expect(PrettyText.cook("💣")).not_to match(/\:bomb\:/)
    end

    it "doesn't replace emoji if emoji is disabled" do
      SiteSetting.enable_emoji = false
      expect(PrettyText.cook(":bomb:")).to eq("<p>:bomb:</p>")
    end

    it "doesn't replace shortcuts if disabled" do
      SiteSetting.enable_emoji_shortcuts = false
      expect(PrettyText.cook(":)")).to eq("<p>:)</p>")
    end

    it "does replace shortcuts if enabled" do
      expect(PrettyText.cook(":)")).to match("smile")
    end

    it "replaces skin toned emoji" do
      expect(PrettyText.cook("hello 👱🏿‍♀️")).to eq("<p>hello <img src=\"/images/emoji/twitter/blonde_woman/6.png?v=5\" title=\":blonde_woman:t6:\" class=\"emoji\" alt=\":blonde_woman:t6:\"></p>")
      expect(PrettyText.cook("hello 👩‍🎤")).to eq("<p>hello <img src=\"/images/emoji/twitter/woman_singer.png?v=5\" title=\":woman_singer:\" class=\"emoji\" alt=\":woman_singer:\"></p>")
      expect(PrettyText.cook("hello 👩🏾‍🎓")).to eq("<p>hello <img src=\"/images/emoji/twitter/woman_student/5.png?v=5\" title=\":woman_student:t5:\" class=\"emoji\" alt=\":woman_student:t5:\"></p>")
      expect(PrettyText.cook("hello 🤷‍♀️")).to eq("<p>hello <img src=\"/images/emoji/twitter/woman_shrugging.png?v=5\" title=\":woman_shrugging:\" class=\"emoji\" alt=\":woman_shrugging:\"></p>")
    end
  end

  describe "custom emoji" do
    it "replaces the custom emoji" do
      CustomEmoji.create!(name: 'trout', upload: Fabricate(:upload))
      Emoji.clear_cache

      expect(PrettyText.cook("hello :trout:")).to match(/<img src[^>]+trout[^>]+>/)
    end
  end

  it "replaces skin toned emoji" do
    expect(PrettyText.cook("hello 👱🏿‍♀️")).to eq("<p>hello <img src=\"/images/emoji/twitter/blonde_woman/6.png?v=5\" title=\":blonde_woman:t6:\" class=\"emoji\" alt=\":blonde_woman:t6:\"></p>")
    expect(PrettyText.cook("hello 👩‍🎤")).to eq("<p>hello <img src=\"/images/emoji/twitter/woman_singer.png?v=5\" title=\":woman_singer:\" class=\"emoji\" alt=\":woman_singer:\"></p>")
    expect(PrettyText.cook("hello 👩🏾‍🎓")).to eq("<p>hello <img src=\"/images/emoji/twitter/woman_student/5.png?v=5\" title=\":woman_student:t5:\" class=\"emoji\" alt=\":woman_student:t5:\"></p>")
    expect(PrettyText.cook("hello 🤷‍♀️")).to eq("<p>hello <img src=\"/images/emoji/twitter/woman_shrugging.png?v=5\" title=\":woman_shrugging:\" class=\"emoji\" alt=\":woman_shrugging:\"></p>")
  end

  it "should not treat a non emoji as an emoji" do
    expect(PrettyText.cook(':email,class_name:')).not_to include('emoji')
  end

  it "supports href schemes" do
    SiteSetting.allowed_href_schemes = "macappstore|steam"
    cooked = cook("[Steam URL Scheme](steam://store/452530)")
    expected = '<p><a href="steam://store/452530" rel="nofollow noopener">Steam URL Scheme</a></p>'
    expect(cooked).to eq(n expected)
  end

  it "supports forbidden schemes" do
    SiteSetting.allowed_href_schemes = "macappstore|itunes"
    cooked = cook("[Steam URL Scheme](steam://store/452530)")
    expected = '<p><a>Steam URL Scheme</a></p>'
    expect(cooked).to eq(n expected)
  end

  it 'allows only tel URL scheme to start with a plus character' do
    SiteSetting.allowed_href_schemes = "tel|steam"
    cooked = cook("[Tel URL Scheme](tel://+452530579785)")
    expected = '<p><a href="tel://+452530579785" rel="nofollow noopener">Tel URL Scheme</a></p>'
    expect(cooked).to eq(n expected)

    cooked2 = cook("[Steam URL Scheme](steam://+store/452530)")
    expected2 = '<p><a>Steam URL Scheme</a></p>'
    expect(cooked2).to eq(n expected2)
  end

  it "produces hashtag links" do
    category = Fabricate(:category, name: 'testing')
    category2 = Fabricate(:category, name: 'known')
    Fabricate(:topic, tags: [Fabricate(:tag, name: 'known')])

    cooked = PrettyText.cook(" #unknown::tag #known #known::tag #testing")

    [
      "<span class=\"hashtag\">#unknown::tag</span>",
      "<a class=\"hashtag\" href=\"#{category2.url_with_id}\">#<span>known</span></a>",
      "<a class=\"hashtag\" href=\"http://test.localhost/tags/known\">#<span>known</span></a>",
      "<a class=\"hashtag\" href=\"#{category.url_with_id}\">#<span>testing</span></a>"
    ].each do |element|

      expect(cooked).to include(element)
    end

    cooked = PrettyText.cook("[`a` #known::tag here](http://example.com)")

    html = <<~HTML
      <p><a href="http://example.com" rel="nofollow noopener"><code>a</code> #known::tag here</a></p>
    HTML

    expect(cooked).to eq(html.strip)

    cooked = PrettyText.cook("<a href='http://example.com'>`a` #known::tag here</a>")

    expect(cooked).to eq(html.strip)

    cooked = PrettyText.cook("<A href='/a'>test</A> #known::tag")
    html = <<~HTML
      <p><a href="/a">test</a> <a class="hashtag" href="http://test.localhost/tags/known">#<span>known</span></a></p>
    HTML

    expect(cooked).to eq(html.strip)

    # ensure it does not fight with the autolinker
    expect(PrettyText.cook(' http://somewhere.com/#known')).not_to include('hashtag')
    expect(PrettyText.cook(' http://somewhere.com/?#known')).not_to include('hashtag')
    expect(PrettyText.cook(' http://somewhere.com/?abc#known')).not_to include('hashtag')

  end

  it "can handle mixed lists" do
    # known bug in old md engine
    cooked = PrettyText.cook("* a\n\n1. b")
    expect(cooked).to match_html("<ul>\n<li>a</li>\n</ul><ol>\n<li>b</li>\n</ol>")
  end

  it "can handle traditional vs non traditional newlines" do
    SiteSetting.traditional_markdown_linebreaks = true
    expect(PrettyText.cook("1\n2")).to match_html "<p>1 2</p>"

    SiteSetting.traditional_markdown_linebreaks = false
    expect(PrettyText.cook("1\n2")).to match_html "<p>1<br>\n2</p>"
  end

  it "can handle emoji by name" do

    expected = <<HTML
<p><img src="/images/emoji/twitter/smile.png?v=5\" title=":smile:" class="emoji" alt=":smile:"><img src="/images/emoji/twitter/sunny.png?v=5" title=":sunny:" class="emoji" alt=":sunny:"></p>
HTML
    expect(PrettyText.cook(":smile::sunny:")).to eq(expected.strip)
  end

  it "handles emoji boundaries correctly" do
    cooked = PrettyText.cook("a,:man:t2:,b")
    expected = '<p>a,<img src="/images/emoji/twitter/man/2.png?v=5" title=":man:t2:" class="emoji" alt=":man:t2:">,b</p>'
    expect(cooked).to match(expected.strip)
  end

  it "can handle emoji by translation" do
    expected = '<p><img src="/images/emoji/twitter/wink.png?v=5" title=":wink:" class="emoji" alt=":wink:"></p>'
    expect(PrettyText.cook(";)")).to eq(expected)
  end

  it "can handle multiple emojis by translation" do
    cooked = PrettyText.cook(":) ;) :)")
    expect(cooked.split("img").length - 1).to eq(3)
  end

  it "handles emoji boundries correctly" do
    expect(PrettyText.cook(",:)")).to include("emoji")
    expect(PrettyText.cook(":-)\n")).to include("emoji")
    expect(PrettyText.cook("a :)")).to include("emoji")
    expect(PrettyText.cook(":),")).not_to include("emoji")
    expect(PrettyText.cook("abcde ^:;-P")).to include("emoji")
  end

  it 'can censor words correctly' do
    begin
      ['apple', 'banana'].each { |w| Fabricate(:watched_word, word: w, action: WatchedWord.actions[:censor]) }
      expect(PrettyText.cook('yay banana yay')).not_to include('banana')
      expect(PrettyText.cook('yay `banana` yay')).not_to include('banana')
      expect(PrettyText.cook("# banana")).not_to include('banana')
      expect(PrettyText.cook("# banana")).to include("\u25a0\u25a0")
    ensure
      $redis.flushall
    end
  end

  it 'supports typographer' do
    SiteSetting.enable_markdown_typographer = true
    expect(PrettyText.cook('(tm)')).to eq('<p>™</p>')

    SiteSetting.enable_markdown_typographer = false
    expect(PrettyText.cook('(tm)')).to eq('<p>(tm)</p>')
  end

  it 'handles onebox correctly' do
    expect(PrettyText.cook("http://a.com\nhttp://b.com").split("onebox").length).to eq(3)
    expect(PrettyText.cook("http://a.com\n\nhttp://b.com").split("onebox").length).to eq(3)
    expect(PrettyText.cook("a\nhttp://a.com")).to include('onebox')
    expect(PrettyText.cook("> http://a.com")).not_to include('onebox')
    expect(PrettyText.cook("a\nhttp://a.com a")).not_to include('onebox')
    expect(PrettyText.cook("a\nhttp://a.com\na")).to include('onebox')
    expect(PrettyText.cook("http://a.com")).to include('onebox')
    expect(PrettyText.cook("http://a.com ")).to include('onebox')
    expect(PrettyText.cook("http://a.com a")).not_to include('onebox')
    expect(PrettyText.cook("- http://a.com")).not_to include('onebox')
    expect(PrettyText.cook("<http://a.com>")).not_to include('onebox')
    expect(PrettyText.cook(" http://a.com")).not_to include('onebox')
    expect(PrettyText.cook("a\n http://a.com")).not_to include('onebox')
    expect(PrettyText.cook("sam@sam.com")).not_to include('onebox')
    expect(PrettyText.cook("<img src='a'>\nhttp://a.com")).to include('onebox')
  end

  it 'handles mini onebox' do
    SiteSetting.enable_inline_onebox_on_all_domains = true
    InlineOneboxer.purge("http://cnn.com/a")

    stub_request(:get, "http://cnn.com/a").
      to_return(status: 200, body: "<html><head><title>news</title></head></html>")

    expect(PrettyText.cook("- http://cnn.com/a\n- a http://cnn.com/a").split("news").length).to eq(3)
    expect(PrettyText.cook("- http://cnn.com/a\n    - a http://cnn.com/a").split("news").length).to eq(3)
  end

  it 'handles mini onebox with query param' do
    SiteSetting.enable_inline_onebox_on_all_domains = true
    InlineOneboxer.purge("http://cnn.com?a")

    stub_request(:get, "http://cnn.com?a").
      to_return(status: 200, body: "<html><head><title>news</title></head></html>")

    expect(PrettyText.cook("- http://cnn.com?a\n- a http://cnn.com?a").split("news").length).to eq(3)
    expect(PrettyText.cook("- http://cnn.com?a\n    - a http://cnn.com?a").split("news").length).to eq(3)
  end

  it 'skips mini onebox for primary domain' do

    # we only include mini onebox if there is something in path or query params

    SiteSetting.enable_inline_onebox_on_all_domains = true
    InlineOneboxer.purge("http://cnn.com/")

    stub_request(:get, "http://cnn.com/").
      to_return(status: 200, body: "<html><head><title>news</title></head></html>")

    expect(PrettyText.cook("- http://cnn.com/\n- a http://cnn.com/").split("news").length).to eq(1)
    expect(PrettyText.cook("- cnn.com\n    - a http://cnn.com/").split("news").length).to eq(1)
  end

  it "can handle bbcode" do
    expect(PrettyText.cook("a[b]b[/b]c")).to eq('<p>a<span class="bbcode-b">b</span>c</p>')
    expect(PrettyText.cook("a[i]b[/i]c")).to eq('<p>a<span class="bbcode-i">b</span>c</p>')
  end

  it "can handle bbcode after a newline" do
    # this is not 100% ideal cause we get an extra p here, but this is pretty rare
    expect(PrettyText.cook("a\n[code]code[/code]")).to eq("<p>a</p>\n<pre><code class=\"lang-auto\">code</code></pre>")

    # this is fine
    expect(PrettyText.cook("a\na[code]code[/code]")).to eq("<p>a<br>\na<code>code</code></p>")
  end

  it "can onebox local topics" do
    op = Fabricate(:post)
    reply = Fabricate(:post, topic_id: op.topic_id)

    url = Discourse.base_url + reply.url
    quote = create_post(topic_id: op.topic.id, raw: "This is a sample reply with a quote\n\n#{url}")
    quote.reload

    expect(quote.cooked).not_to include('[quote')
  end

  it "supports tables" do

    markdown = <<~MD
      | Tables        | Are           | Cool  |
      | ------------- |:-------------:| -----:|
      | col 3 is      | right-aligned | $1600 |
    MD

    expected = <<~HTML
      <div class="md-table">
      <table>
      <thead>
      <tr>
      <th>Tables</th>
      <th style="text-align:center">Are</th>
      <th style="text-align:right">Cool</th>
      </tr>
      </thead>
      <tbody>
      <tr>
      <td>col 3 is</td>
      <td style="text-align:center">right-aligned</td>
      <td style="text-align:right">$1600</td>
      </tr>
      </tbody>
      </table>
      </div>
    HTML

    expect(PrettyText.cook(markdown)).to eq(expected.strip)
  end

  it "supports img bbcode" do
    cooked = PrettyText.cook "[img]http://www.image/test.png[/img]"
    html = "<p><img src=\"http://www.image/test.png\" alt></p>"
    expect(cooked).to eq(html)
  end

  it "provides safety for img bbcode" do
    cooked = PrettyText.cook "[img]http://aaa.com<script>alert(1);</script>[/img]"
    html = '<p><img src="http://aaa.com&lt;script&gt;alert(1);&lt;/script&gt;" alt></p>'
    expect(cooked).to eq(html)
  end

  it "supports email bbcode" do
    cooked = PrettyText.cook "[email]sam@sam.com[/email]"
    html = '<p><a href="mailto:sam@sam.com" data-bbcode="true">sam@sam.com</a></p>'
    expect(cooked).to eq(html)
  end

  it "supports url bbcode" do
    cooked = PrettyText.cook "[url]http://sam.com[/url]"
    html = '<p><a href="http://sam.com" data-bbcode="true" rel="nofollow noopener">http://sam.com</a></p>';
    expect(cooked).to eq(html)
  end

  it "supports nesting tags in url" do
    cooked = PrettyText.cook("[url=http://sam.com][b]I am sam[/b][/url]")
    html = '<p><a href="http://sam.com" data-bbcode="true" rel="nofollow noopener"><span class="bbcode-b">I am sam</span></a></p>';
    expect(cooked).to eq(html)
  end

  it "supports query params in bbcode url" do
    cooked = PrettyText.cook("[url=https://www.amazon.com/Camcorder-Hausbell-302S-Control-Infrared/dp/B01KLOA1PI/?tag=discourse]BBcode link[/url]")
    html = '<p><a href="https://www.amazon.com/Camcorder-Hausbell-302S-Control-Infrared/dp/B01KLOA1PI/?tag=discourse" data-bbcode="true" rel="nofollow noopener">BBcode link</a></p>'
    expect(cooked).to eq(html)
  end

  it "supports inline code bbcode" do
    cooked = PrettyText.cook "Testing [code]codified **stuff** and `more` stuff[/code]"
    html = "<p>Testing <code>codified **stuff** and `more` stuff</code></p>"
    expect(cooked).to eq(html)
  end

  it "supports block code bbcode" do
    cooked = PrettyText.cook "[code]\ncodified\n\n\n  **stuff** and `more` stuff\n[/code]"
    html = "<pre><code class=\"lang-auto\">codified\n\n\n  **stuff** and `more` stuff</code></pre>"
    expect(cooked).to eq(html)
  end

  it "support special handling for space in urls" do
    cooked = PrettyText.cook "http://testing.com?a%20b"
    html = '<p><a href="http://testing.com?a%20b" class="onebox" target="_blank" rel="nofollow noopener">http://testing.com?a%20b</a></p>'
    expect(cooked).to eq(html)
  end

  it "supports onebox for decoded urls" do
    cooked = PrettyText.cook "http://testing.com?a%50b"
    html = '<p><a href="http://testing.com?a%50b" class="onebox" target="_blank" rel="nofollow noopener">http://testing.com?aPb</a></p>'
    expect(cooked).to eq(html)
  end

  it "should sanitize the html" do
    expect(PrettyText.cook("<test>alert(42)</test>")).to eq "<p>alert(42)</p>"
  end

  it "should not onebox magically linked urls" do
    expect(PrettyText.cook('[url]site.com[/url]')).not_to include('onebox')
  end

  it "should sanitize the html" do
    expect(PrettyText.cook("<p class='hi'>hi</p>")).to eq "<p>hi</p>"
  end

  it "should strip SCRIPT" do
    expect(PrettyText.cook("<script>alert(42)</script>")).to eq ""
  end

  it "should allow sanitize bypass" do
    expect(PrettyText.cook("<test>alert(42)</test>", sanitize: false)).to eq "<p><test>alert(42)</test></p>"
  end

  # custom rule used to specify image dimensions via alt tags
  describe "image dimensions" do
    it "allows title plus dimensions" do
      cooked = PrettyText.cook <<~MD
        ![title with | title|220x100](http://png.com/my.png)
        ![](http://png.com/my.png)
        ![|220x100](http://png.com/my.png)
        ![stuff](http://png.com/my.png)
        ![|220x100,50%](http://png.com/my.png)
      MD

      html = <<~HTML
        <p><img src="http://png.com/my.png" alt="title with | title" width="220" height="100"><br>
        <img src="http://png.com/my.png" alt><br>
        <img src="http://png.com/my.png" alt width="220" height="100"><br>
        <img src="http://png.com/my.png" alt="stuff"><br>
        <img src="http://png.com/my.png" alt width="110" height="50"></p>
      HTML

      expect(cooked).to eq(html.strip)
    end

    it "allows whitespace before the percent scaler" do
      cooked = PrettyText.cook <<~MD
        ![|220x100, 50%](http://png.com/my.png)
        ![|220x100 , 50%](http://png.com/my.png)
        ![|220x100 ,50%](http://png.com/my.png)
      MD

      html = <<~HTML
        <p><img src="http://png.com/my.png" alt width="110" height="50"><br>
        <img src="http://png.com/my.png" alt width="110" height="50"><br>
        <img src="http://png.com/my.png" alt width="110" height="50"></p>
      HTML

      expect(cooked).to eq(html.strip)
    end

  end

  describe "inline onebox" do
    it "includes the topic title" do
      topic = Fabricate(:topic)

      raw = "Hello #{topic.url}"

      cooked = <<~HTML
        <p>Hello <a href="#{topic.url}">#{topic.title}</a></p>
      HTML

      expect(PrettyText.cook(raw)).to eq(cooked.strip)
    end
  end

  describe "image decoding" do

    it "can decode upload:// for default setup" do
      upload = Fabricate(:upload)

      raw = <<~RAW
      ![upload](#{upload.short_url})

      - ![upload](#{upload.short_url})

      - test
          - ![upload](#{upload.short_url})
      RAW

      cooked = <<~HTML
        <p><img src="#{upload.url}" alt="upload"></p>
        <ul>
        <li>
        <p><img src="#{upload.url}" alt="upload"></p>
        </li>
        <li>
        <p>test</p>
        <ul>
        <li><img src="#{upload.url}" alt="upload"></li>
        </ul>
        </li>
        </ul>
      HTML

      expect(PrettyText.cook(raw)).to eq(cooked.strip)
    end

    it "can place a blank image if we can not find the upload" do

      raw = "![upload](upload://abcABC.png)"

      cooked = <<~HTML
        <p><img src="/images/transparent.png" alt="upload" data-orig-src="upload://abcABC.png"></p>
      HTML

      expect(PrettyText.cook(raw)).to eq(cooked.strip)
    end

  end

  it "can properly whitelist iframes" do
    SiteSetting.allowed_iframes = "https://bob.com/a|http://silly.com?EMBED="
    raw = <<~IFRAMES
      <iframe src='https://www.google.com/maps/Embed?testing'></iframe>
      <iframe src='https://bob.com/a?testing'></iframe>
      <iframe src='HTTP://SILLY.COM?EMBED=111'></iframe>
    IFRAMES

    # we require explicit HTTPS here
    html = <<~IFRAMES
      <iframe src="https://bob.com/a?testing"></iframe>
      <iframe src="HTTP://SILLY.COM?EMBED=111"></iframe>
    IFRAMES

    cooked = PrettyText.cook(raw).strip

    expect(cooked).to eq(html.strip)

  end

  it "You can disable linkify" do
    md = "www.cnn.com test.it http://test.com https://test.ab https://a"
    cooked = PrettyText.cook(md)

    html = <<~HTML
      <p><a href="http://www.cnn.com" rel="nofollow noopener">www.cnn.com</a> test.it <a href="http://test.com" rel="nofollow noopener">http://test.com</a> <a href="https://test.ab" rel="nofollow noopener">https://test.ab</a> <a href="https://a" rel="nofollow noopener">https://a</a></p>
    HTML

    expect(cooked).to eq(html.strip)

    # notice how cnn.com is no longer linked but it is
    SiteSetting.markdown_linkify_tlds = "not_com|it"

    cooked = PrettyText.cook(md)
    html = <<~HTML
    <p>www.cnn.com <a href="http://test.it" rel="nofollow noopener">test.it</a> <a href="http://test.com" rel="nofollow noopener">http://test.com</a> <a href="https://test.ab" rel="nofollow noopener">https://test.ab</a> <a href="https://a" rel="nofollow noopener">https://a</a></p>
    HTML

    expect(cooked).to eq(html.strip)

    # no tlds anymore
    SiteSetting.markdown_linkify_tlds = ""

    cooked = PrettyText.cook(md)
    html = <<~HTML
      <p>www.cnn.com test.it <a href="http://test.com" rel="nofollow noopener">http://test.com</a> <a href="https://test.ab" rel="nofollow noopener">https://test.ab</a> <a href="https://a" rel="nofollow noopener">https://a</a></p>
    HTML

    expect(cooked).to eq(html.strip)

    # lastly ... what about no linkify
    SiteSetting.enable_markdown_linkify = false

    cooked = PrettyText.cook(md)

    html = <<~HTML
      <p>www.cnn.com test.it http://test.com https://test.ab https://a</p>
    HTML
  end

  it "has a proper data whitlist on div" do
    cooked = PrettyText.cook("<div data-theme-a='a'>test</div>")
    expect(cooked).to include("data-theme-a")
  end

end
