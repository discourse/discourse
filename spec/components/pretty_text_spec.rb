require 'spec_helper'
require 'pretty_text'

describe PrettyText do

  describe "Cooking" do

    describe "with avatar" do

      before(:each) do
        eviltrout = User.new
        eviltrout.stubs(:avatar_template).returns("http://test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/{size}.png")
        User.expects(:find_by).with(username_lower: "eviltrout").returns(eviltrout)
      end

      it "produces a quote even with new lines in it" do
        PrettyText.cook("[quote=\"EvilTrout, post:123, topic:456, full:true\"]ddd\n[/quote]").should match_html "<aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">\n<div class=\"quote-controls\"></div>\n<img width=\"20\" height=\"20\" src=\"http://test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png\" class=\"avatar\">EvilTrout:</div>\n<blockquote><p>ddd</p></blockquote></aside>"
      end

      it "should produce a quote" do
        PrettyText.cook("[quote=\"EvilTrout, post:123, topic:456, full:true\"]ddd[/quote]").should match_html "<aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">\n<div class=\"quote-controls\"></div>\n<img width=\"20\" height=\"20\" src=\"http://test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png\" class=\"avatar\">EvilTrout:</div>\n<blockquote><p>ddd</p></blockquote></aside>"
      end

      it "trims spaces on quote params" do
        PrettyText.cook("[quote=\"EvilTrout, post:555, topic: 666\"]ddd[/quote]").should match_html "<aside class=\"quote\" data-post=\"555\" data-topic=\"666\"><div class=\"title\">\n<div class=\"quote-controls\"></div>\n<img width=\"20\" height=\"20\" src=\"http://test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png\" class=\"avatar\">EvilTrout:</div>\n<blockquote><p>ddd</p></blockquote></aside>"
      end

    end

    it "should handle 3 mentions in a row" do
      PrettyText.cook('@hello @hello @hello').should match_html "<p><span class=\"mention\">@hello</span> <span class=\"mention\">@hello</span> <span class=\"mention\">@hello</span></p>"
    end

    it "should sanitize the html" do
      PrettyText.cook("<script>alert(42)</script>").should match_html "<p></p>"
    end

    it 'should allow for @mentions to have punctuation' do
      PrettyText.cook("hello @bob's @bob,@bob; @bob\"").should
        match_html "<p>hello <span class=\"mention\">@bob</span>'s <span class=\"mention\">@bob</span>,<span class=\"mention\">@bob</span>; <span class=\"mention\">@bob</span>\"</p>"
    end

    # see: https://github.com/sparklemotion/nokogiri/issues/1173
    skip 'allows html entities correctly' do
      PrettyText.cook("&aleph;&pound;&#162;").should == "<p>&aleph;&pound;&#162;</p>"
    end

  end

  describe "rel nofollow" do
    before do
      SiteSetting.stubs(:add_rel_nofollow_to_user_content).returns(true)
      SiteSetting.stubs(:exclude_rel_nofollow_domains).returns("foo.com|bar.com")
    end

    it "should inject nofollow in all user provided links" do
      PrettyText.cook('<a href="http://cnn.com">cnn</a>').should =~ /nofollow/
    end

    it "should not inject nofollow in all local links" do
      (PrettyText.cook("<a href='#{Discourse.base_url}/test.html'>cnn</a>") !~ /nofollow/).should == true
    end

    it "should not inject nofollow in all subdomain links" do
      (PrettyText.cook("<a href='#{Discourse.base_url.sub('http://', 'http://bla.')}/test.html'>cnn</a>") !~ /nofollow/).should == true
    end

    it "should not inject nofollow for foo.com" do
      (PrettyText.cook("<a href='http://foo.com/test.html'>cnn</a>") !~ /nofollow/).should == true
    end

    it "should not inject nofollow for bar.foo.com" do
      (PrettyText.cook("<a href='http://bar.foo.com/test.html'>cnn</a>") !~ /nofollow/).should == true
    end

    it "should not inject nofollow if omit_nofollow option is given" do
      (PrettyText.cook('<a href="http://cnn.com">cnn</a>', omit_nofollow: true) !~ /nofollow/).should == true
    end
  end

  describe "Excerpt" do

    it "sanitizes attempts to inject invalid attributes" do

      spinner = "<a href=\"http://thedailywtf.com/\" data-bbcode=\"' class='fa fa-spin\">WTF</a>"
      PrettyText.excerpt(spinner, 20).should match_html spinner

      spinner = %q{<a href="http://thedailywtf.com/" title="' class=&quot;fa fa-spin&quot;&gt;&lt;img src='http://thedailywtf.com/Resources/Images/Primary/logo.gif"></a>}
      PrettyText.excerpt(spinner, 20).should match_html spinner
    end

    context "images" do

      it "should dump images" do
        PrettyText.excerpt("<img src='http://cnn.com/a.gif'>",100).should == "[image]"
      end

      it "should keep alt tags" do
        PrettyText.excerpt("<img src='http://cnn.com/a.gif' alt='car' title='my big car'>",100).should == "[car]"
      end

      it "should keep title tags" do
        PrettyText.excerpt("<img src='http://cnn.com/a.gif' title='car'>",100).should == "[car]"
      end

      it "should convert images to markdown if the option is set" do
        PrettyText.excerpt("<img src='http://cnn.com/a.gif' title='car'>", 100, markdown_images: true).should == "![car](http://cnn.com/a.gif)"
      end

      it "should keep spoilers" do
        PrettyText.excerpt("<div class='spoiler'><img src='http://cnn.com/a.gif'></div>", 100).should match_html "<span class='spoiler'>[image]</span>"
        PrettyText.excerpt("<span class='spoiler'>spoiler</div>", 100).should match_html "<span class='spoiler'>spoiler</span>"
      end
    end

    it "should have an option to strip links" do
      PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>",100, strip_links: true).should == "cnn"
    end

    it "should preserve links" do
      PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>",100).should match_html "<a href='http://cnn.com'>cnn</a>"
    end

    it "should deal with special keys properly" do
      PrettyText.excerpt("<pre><b></pre>",100).should == ""
    end

    it "should truncate stuff properly" do
      PrettyText.excerpt("hello world",5).should == "hello&hellip;"
      PrettyText.excerpt("<p>hello</p><p>world</p>",6).should == "hello w&hellip;"
    end

    it "should insert a space between to Ps" do
      PrettyText.excerpt("<p>a</p><p>b</p>",5).should == "a b"
    end

    it "should strip quotes" do
      PrettyText.excerpt("<aside class='quote'><p>a</p><p>b</p></aside>boom",5).should == "boom"
    end

    it "should not count the surrounds of a link" do
      PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>",3).should match_html "<a href='http://cnn.com'>cnn</a>"
    end

    it "uses an ellipsis instead of html entities if provided with the option" do
      PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>", 2, text_entities: true).should match_html "<a href='http://cnn.com'>cn...</a>"
    end

    it "should truncate links" do
      PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>",2).should match_html "<a href='http://cnn.com'>cn&hellip;</a>"
    end

    it "doesn't extract empty quotes as links" do
      PrettyText.extract_links("<aside class='quote'>not a linked quote</aside>\n").to_a.should be_empty
    end

    def extract_urls(text)
      PrettyText.extract_links(text).map(&:url).to_a
    end

    it "should be able to extract links" do
      extract_urls("<a href='http://cnn.com'>http://bla.com</a>").should == ["http://cnn.com"]
    end

    it "should extract links to topics" do
      extract_urls("<aside class=\"quote\" data-topic=\"321\">aside</aside>").should == ["/t/topic/321"]
    end

    it "should extract links to posts" do
      extract_urls("<aside class=\"quote\" data-topic=\"1234\" data-post=\"4567\">aside</aside>").should == ["/t/topic/1234/4567"]
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

      links.map{|l| [l.url, l.is_quote]}.to_a.sort.should ==
        [["http://body_only.com",false],
         ["http://body_and_quote.com", false],
         ["/t/topic/1234",true]
        ].sort
    end

    it "should not preserve tags in code blocks" do
      PrettyText.excerpt("<pre><code class='handlebars'>&lt;h3&gt;Hours&lt;/h3&gt;</code></pre>",100).should == "&lt;h3&gt;Hours&lt;/h3&gt;"
    end

    it "should handle nil" do
      PrettyText.excerpt(nil,100).should == ''
    end

    it "handles span excerpt at the beginning of a post" do
      PrettyText.excerpt("<span class='excerpt'>hi</span> test",100).should == 'hi'
      post = Fabricate(:post, raw: "<span class='excerpt'>hi</span> test")
      post.excerpt.should == "hi"
    end

    it "ignores max excerpt length if a span excerpt is specified" do
      two_hundred = "123456789 " * 20 + "."
      text =  two_hundred + "<span class='excerpt'>#{two_hundred}</span>" + two_hundred
      PrettyText.excerpt(text, 100).should == two_hundred
      post = Fabricate(:post, raw: text)
      post.excerpt.should == two_hundred
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

  describe "make_all_links_absolute" do
    let(:base_url) { "http://baseurl.net" }

    def make_abs_string(html)
      doc = Nokogiri::HTML.fragment(html)
      described_class.make_all_links_absolute(doc)
      doc.to_html
    end

    before do
      Discourse.stubs(:base_url).returns(base_url)
    end

    it "adds base url to relative links" do
      html = "<p><a class=\"mention\" href=\"/users/wiseguy\">@wiseguy</a>, <a class=\"mention\" href=\"/users/trollol\">@trollol</a> what do you guys think? </p>"
      output = make_abs_string(html)
      output.should == "<p><a class=\"mention\" href=\"#{base_url}/users/wiseguy\">@wiseguy</a>, <a class=\"mention\" href=\"#{base_url}/users/trollol\">@trollol</a> what do you guys think? </p>"
    end

    it "doesn't change external absolute links" do
      html = "<p>Check out <a href=\"http://mywebsite.com/users/boss\">this guy</a>.</p>"
      make_abs_string(html).should == html
    end

    it "doesn't change internal absolute links" do
      html = "<p>Check out <a href=\"#{base_url}/users/boss\">this guy</a>.</p>"
      make_abs_string(html).should == html
    end

    it "can tolerate invalid URLs" do
      html = "<p>Check out <a href=\"not a real url\">this guy</a>.</p>"
      expect { make_abs_string(html) }.to_not raise_error
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
      strip_image_wrapping(html).should == html
    end

    let(:wrapped_image) { "<div class=\"lightbox-wrapper\"><a href=\"//localhost:3000/uploads/default/4399/33691397e78b4d75.png\" class=\"lightbox\" title=\"Screen Shot 2014-04-14 at 9.47.10 PM.png\"><img src=\"//localhost:3000/uploads/default/_optimized/bd9/b20/bbbcd6a0c0_655x500.png\" width=\"655\" height=\"500\"><div class=\"meta\">\n<span class=\"filename\">Screen Shot 2014-04-14 at 9.47.10 PM.png</span><span class=\"informations\">966x737 1.47 MB</span><span class=\"expand\"></span>\n</div></a></div>" }

    it "strips the metadata" do
      strip_image_wrapping(wrapped_image).should == "<div class=\"lightbox-wrapper\"><a href=\"//localhost:3000/uploads/default/4399/33691397e78b4d75.png\" class=\"lightbox\" title=\"Screen Shot 2014-04-14 at 9.47.10 PM.png\"><img src=\"//localhost:3000/uploads/default/_optimized/bd9/b20/bbbcd6a0c0_655x500.png\" width=\"655\" height=\"500\"></a></div>"
    end
  end

  describe 'format_for_email' do
    it 'does not crash' do
      PrettyText.format_for_email('<a href="mailto:michael.brown@discourse.org?subject=Your%20post%20at%20http://try.discourse.org/t/discussion-happens-so-much/127/1000?u=supermathie">test</a>')
    end
  end


end
