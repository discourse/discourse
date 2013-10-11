require 'spec_helper'
require 'pretty_text'

describe PrettyText do

  describe "Cooking" do

    describe "with avatar" do

      before(:each) do
        eviltrout = User.new
        eviltrout.stubs(:avatar_template).returns("http://test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/{size}.png")
        User.expects(:where).with(username_lower: "eviltrout").returns([eviltrout])
      end

      it "produces a quote even with new lines in it" do
        PrettyText.cook("[quote=\"EvilTrout, post:123, topic:456, full:true\"]ddd\n[/quote]").should match_html "<p><aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">\n<div class=\"quote-controls\"></div>\n<img width=\"20\" height=\"20\" src=\"http://test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png\" class=\"avatar\">EvilTrout said:</div>\n<blockquote><p>ddd</p></blockquote></aside></p>"
      end

      it "should produce a quote" do
        PrettyText.cook("[quote=\"EvilTrout, post:123, topic:456, full:true\"]ddd[/quote]").should match_html "<p><aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">\n<div class=\"quote-controls\"></div>\n<img width=\"20\" height=\"20\" src=\"http://test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png\" class=\"avatar\">EvilTrout said:</div>\n<blockquote><p>ddd</p></blockquote></aside></p>"
      end

      it "trims spaces on quote params" do
        PrettyText.cook("[quote=\"EvilTrout, post:555, topic: 666\"]ddd[/quote]").should match_html "<p><aside class=\"quote\" data-post=\"555\" data-topic=\"666\"><div class=\"title\">\n<div class=\"quote-controls\"></div>\n<img width=\"20\" height=\"20\" src=\"http://test.localhost/uploads/default/avatars/42d/57c/46ce7ee487/40.png\" class=\"avatar\">EvilTrout said:</div>\n<blockquote><p>ddd</p></blockquote></aside></p>"
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

    it 'should add spoiler tags' do
      PrettyText.cook("[spoiler]hello[/spoiler]").should match_html "<p><span class=\"spoiler\">hello</span></p>"
    end
  end

  describe "rel nofollow" do
    before do
      SiteSetting.stubs(:add_rel_nofollow_to_user_content).returns(true)
      SiteSetting.stubs(:exclude_rel_nofollow_domains).returns("foo.com,bar.com")
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

  describe "apply cdn" do
    it "should detect bare links to images and apply a CDN" do
      PrettyText.apply_cdn("<a href='/hello.png'>hello</a><img src='/a.jpeg'>","http://a.com").should ==
        "<a href=\"http://a.com/hello.png\">hello</a><img src=\"http://a.com/a.jpeg\">"
    end

    it "should not touch non images" do
      PrettyText.apply_cdn("<a href='/hello'>hello</a>","http://a.com").should ==
        "<a href=\"/hello\">hello</a>"
    end

    it "should not touch schemaless links" do
      PrettyText.apply_cdn("<a href='//hello'>hello</a>","http://a.com").should ==
        "<a href=\"//hello\">hello</a>"
    end
  end
end
