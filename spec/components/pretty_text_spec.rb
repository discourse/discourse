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
        PrettyText.cook("[quote=\"EvilTrout, post:123, topic:456, full:true\"]ddd\n[/quote]").should match_html "<aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">\n<div class=\"quote-controls\"></div>\n<img width=\"20\" height=\"20\" src=\"http://test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png\" class=\"avatar\">EvilTrout said:</div>\n<blockquote><p>ddd</p></blockquote></aside>"
      end

      it "should produce a quote" do
        PrettyText.cook("[quote=\"EvilTrout, post:123, topic:456, full:true\"]ddd[/quote]").should match_html "<aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">\n<div class=\"quote-controls\"></div>\n<img width=\"20\" height=\"20\" src=\"http://test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png\" class=\"avatar\">EvilTrout said:</div>\n<blockquote><p>ddd</p></blockquote></aside>"
      end

      it "trims spaces on quote params" do
        PrettyText.cook("[quote=\"EvilTrout, post:555, topic: 666\"]ddd[/quote]").should match_html "<aside class=\"quote\" data-post=\"555\" data-topic=\"666\"><div class=\"title\">\n<div class=\"quote-controls\"></div>\n<img width=\"20\" height=\"20\" src=\"http://test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png\" class=\"avatar\">EvilTrout said:</div>\n<blockquote><p>ddd</p></blockquote></aside>"
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
      (PrettyText.cook("<a href='#{Discourse.base_url}/test.html'>cnn</a>") !~ /nofollow/).should be_true
    end

    it "should not inject nofollow in all subdomain links" do
      (PrettyText.cook("<a href='#{Discourse.base_url.sub('http://', 'http://bla.')}/test.html'>cnn</a>") !~ /nofollow/).should be_true
    end

    it "should not inject nofollow for foo.com" do
      (PrettyText.cook("<a href='http://foo.com/test.html'>cnn</a>") !~ /nofollow/).should be_true
    end

    it "should not inject nofollow for bar.foo.com" do
      (PrettyText.cook("<a href='http://bar.foo.com/test.html'>cnn</a>") !~ /nofollow/).should be_true
    end

    it "should not inject nofollow if omit_nofollow option is given" do
      (PrettyText.cook('<a href="http://cnn.com">cnn</a>', omit_nofollow: true) !~ /nofollow/).should be_true
    end
  end

  describe "Excerpt" do

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
        PrettyText.excerpt("<div class='spoiler'><img src='http://cnn.com/a.gif'></div>", 100).should == "<span class='spoiler'>[image]</span>"
        PrettyText.excerpt("<span class='spoiler'>spoiler</div>", 100).should == "<span class='spoiler'>spoiler</span>"
      end
    end

    it "should have an option to strip links" do
      PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>",100, strip_links: true).should == "cnn"
    end

    it "should preserve links" do
      PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>",100).should == "<a href='http://cnn.com'>cnn</a>"
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
      PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>",3).should == "<a href='http://cnn.com'>cnn</a>"
    end

    it "uses an ellipsis instead of html entities if provided with the option" do
      PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>", 2, text_entities: true).should == "<a href='http://cnn.com'>cn...</a>"
    end

    it "should truncate links" do
      PrettyText.excerpt("<a href='http://cnn.com'>cnn</a>",2).should == "<a href='http://cnn.com'>cn&hellip;</a>"
    end

    it "doesn't extract empty quotes as links" do
      PrettyText.extract_links("<aside class='quote'>not a linked quote</aside>\n").to_a.should be_empty
    end

    it "should be able to extract links" do
      PrettyText.extract_links("<a href='http://cnn.com'>http://bla.com</a>").to_a.should == ["http://cnn.com"]
    end

    it "should extract links to topics" do
      PrettyText.extract_links("<aside class=\"quote\" data-topic=\"321\">aside</aside>").to_a.should == ["/t/topic/321"]
    end

    it "should extract links to posts" do
      PrettyText.extract_links("<aside class=\"quote\" data-topic=\"1234\" data-post=\"4567\">aside</aside>").to_a.should == ["/t/topic/1234/4567"]
    end

    it "should not extract links inside quotes" do
      PrettyText.extract_links("
        <a href='http://body_only.com'>http://useless1.com</a>
        <aside class=\"quote\" data-topic=\"1234\">
          <a href='http://body_and_quote.com'>http://useless3.com</a>
          <a href='http://quote_only.com'>http://useless4.com</a>
        </aside>
        <a href='http://body_and_quote.com'>http://useless2.com</a>
        ").to_a.should == ["http://body_only.com", "http://body_and_quote.com", "/t/topic/1234"]
    end

    it "should not preserve tags in code blocks" do
      PrettyText.excerpt("<pre><code class='handlebars'>&lt;h3&gt;Hours&lt;/h3&gt;</code></pre>",100).should == "&lt;h3&gt;Hours&lt;/h3&gt;"
    end

    it "should handle nil" do
      PrettyText.excerpt(nil,100).should == ''
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


  describe "markdown quirks" do
    it "bolds stuff in parens" do
      PrettyText.cook("a \"**hello**\"").should match_html "<p>a &quot;<strong>hello</strong>&quot;</p>"
      PrettyText.cook("(**hello**)").should match_html "<p>(<strong>hello</strong>)</p>"
      #           is it me your looking for?
    end
    it "allows for newline after bold" do
      PrettyText.cook("**hello**\nworld").should match_html "<p><strong>hello</strong><br />world</p>"
    end
    it "allows for newline for 2 bolds" do
      PrettyText.cook("**hello**\n**world**").should match_html "<p><strong>hello</strong><br /><strong>world</strong></p>"
    end

    it "allows for * and _  in bold" do
      PrettyText.cook("**a*_b**").should match_html "<p><strong>a*_b</strong></p>"
    end

    it "does not apply italics when there is a space inside" do
      PrettyText.cook("** hello**").should match_html "<p>** hello**</p>"
      PrettyText.cook("**hello **").should match_html "<p>**hello **</p>"
    end

    it "allows does not bold chinese intra word" do
      PrettyText.cook("你**hello**").should match_html "<p>你**hello**</p>"
    end

    it "allows bold chinese" do
      PrettyText.cook("**你hello**").should match_html "<p><strong>你hello</strong></p>"
    end
  end

end
