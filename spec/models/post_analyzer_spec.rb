require 'rails_helper'

describe PostAnalyzer do

  let(:default_topic_id) { 12 }
  let(:url) { 'https://twitter.com/evil_trout/status/345954894420787200' }

  describe '#cook' do
    let(:post_analyzer) { PostAnalyzer.new nil, nil  }

    let(:raw) { "Here's a tweet:\n#{url}" }
    let(:options) { {} }

    before { Oneboxer.stubs(:onebox) }

    it 'fetches the cached onebox for any urls in the post' do
      Oneboxer.expects(:cached_onebox).with url
      post_analyzer.cook(raw, options)
      expect(post_analyzer.found_oneboxes?).to be(true)
    end

    it 'does not invalidate the onebox cache' do
      Oneboxer.expects(:invalidate).with(url).never
      post_analyzer.cook(raw, options)
    end

    context 'when invalidating oneboxes' do
      let(:options) { { invalidate_oneboxes: true } }

      it 'invalidates the oneboxes for urls in the post' do
        Oneboxer.expects(:invalidate).with url
        post_analyzer.cook(raw, options)
      end
    end

    it "does nothing when the cook_method is 'raw_html'" do
      cooked = post_analyzer.cook('Hello <div/> world', cook_method: Post.cook_methods[:raw_html])
      expect(cooked).to eq('Hello <div/> world')
    end

    it "does not interpret Markdown when cook_method is 'email' and raw contains plaintext" do
      cooked = post_analyzer.cook("[plaintext]\n*this is not italic* and here is a link: https://www.example.com\n[/plaintext]", cook_method: Post.cook_methods[:email])
      expect(cooked).to eq('*this is not italic* and here is a link: <a href="https://www.example.com">https://www.example.com</a>')
    end

    it "does interpret Markdown when cook_method is 'email' and raw does not contain plaintext" do
      cooked = post_analyzer.cook('*this is italic*', cook_method: Post.cook_methods[:email])
      expect(cooked).to eq('<p><em>this is italic</em></p>')
    end

    it "does interpret Markdown when cook_method is 'regular'" do
      cooked = post_analyzer.cook('*this is italic*', cook_method: Post.cook_methods[:regular])
      expect(cooked).to eq('<p><em>this is italic</em></p>')
    end

    it "does interpret Markdown when not cook_method is set" do
      cooked = post_analyzer.cook('*this is italic*')
      expect(cooked).to eq('<p><em>this is italic</em></p>')
    end
  end

  context "links" do
    let(:raw_no_links) { "hello world my name is evil trout" }
    let(:raw_one_link_md) { "[jlawr](http://www.imdb.com/name/nm2225369)" }
    let(:raw_two_links_html) { "<a href='http://disneyland.disney.go.com/'>disney</a> <a href='http://reddit.com'>reddit</a>" }
    let(:raw_three_links) { "http://discourse.org and http://discourse.org/another_url and http://www.imdb.com/name/nm2225369" }
    let(:raw_elided) { "<details class='elided'>\n<summary title='Show trimmed content'>&#183;&#183;&#183;</summary>\nhttp://discourse.org\n</details>" }

    describe "raw_links" do
      it "returns a blank collection for a post with no links" do
        post_analyzer = PostAnalyzer.new(raw_no_links, default_topic_id)
        expect(post_analyzer.raw_links).to be_blank
      end

      it "finds a link within markdown" do
        post_analyzer = PostAnalyzer.new(raw_one_link_md, default_topic_id)
        expect(post_analyzer.raw_links).to eq(["http://www.imdb.com/name/nm2225369"])
      end

      it "can find two links from html" do
        post_analyzer = PostAnalyzer.new(raw_two_links_html, default_topic_id)
        expect(post_analyzer.raw_links).to eq(["http://disneyland.disney.go.com/", "http://reddit.com"])
      end

      it "can find three links without markup" do
        post_analyzer = PostAnalyzer.new(raw_three_links, default_topic_id)
        expect(post_analyzer.raw_links).to eq(["http://discourse.org", "http://discourse.org/another_url", "http://www.imdb.com/name/nm2225369"])
      end

      it "doesn't extract links from elided part" do
        post_analyzer = PostAnalyzer.new(raw_elided, default_topic_id)
        post_analyzer.expects(:cook).returns("<p><details class='elided'>\n<summary title='Show trimmed content'>&#183;&#183;&#183;</summary>\n<a href='http://discourse.org'>discourse.org</a>\n</details></p>")
        expect(post_analyzer.raw_links).to be_blank
      end
    end

    describe "linked_hosts" do
      it "returns blank with no links" do
        post_analyzer = PostAnalyzer.new(raw_no_links, default_topic_id)
        expect(post_analyzer.linked_hosts).to be_blank
      end

      it "returns the host and a count for links" do
        post_analyzer = PostAnalyzer.new(raw_two_links_html, default_topic_id)
        expect(post_analyzer.linked_hosts).to eq("disneyland.disney.go.com" => 1, "reddit.com" => 1)
      end

      it "it counts properly with more than one link on the same host" do
        post_analyzer = PostAnalyzer.new(raw_three_links, default_topic_id)
        expect(post_analyzer.linked_hosts).to eq("discourse.org" => 1, "www.imdb.com" => 1)
      end
    end
  end

  describe "image_count" do
    let(:raw_post_one_image_md) { "![sherlock](http://bbc.co.uk/sherlock.jpg)" }
    let(:raw_post_two_images_html) { "<img src='http://discourse.org/logo.png'> <img src='http://bbc.co.uk/sherlock.jpg'>" }
    let(:raw_post_with_avatars) { '<img alt="smiley" title=":smiley:" src="/assets/emoji/smiley.png" class="avatar"> <img alt="wink" title=":wink:" src="/assets/emoji/wink.png" class="avatar">' }
    let(:raw_post_with_favicon) { '<img src="/assets/favicons/wikipedia.png" class="favicon">' }
    let(:raw_post_with_thumbnail) { '<img src="/assets/emoji/smiley.png" class="thumbnail">' }
    let(:raw_post_with_two_classy_images) { "<img src='http://discourse.org/logo.png' class='classy'> <img src='http://bbc.co.uk/sherlock.jpg' class='classy'>" }

    it "returns 0 images for an empty post" do
      post_analyzer = PostAnalyzer.new("Hello world", nil)
      expect(post_analyzer.image_count).to eq(0)
    end

    it "finds images from markdown" do
      post_analyzer = PostAnalyzer.new(raw_post_one_image_md, default_topic_id)
      expect(post_analyzer.image_count).to eq(1)
    end

    it "finds images from HTML" do
      post_analyzer = PostAnalyzer.new(raw_post_two_images_html, default_topic_id)
      expect(post_analyzer.image_count).to eq(2)
    end

    it "doesn't count avatars as images" do
      post_analyzer = PostAnalyzer.new(raw_post_with_avatars, default_topic_id)
      PrettyText.stubs(:cook).returns(raw_post_with_avatars)
      expect(post_analyzer.image_count).to eq(0)
    end

    it "doesn't count favicons as images" do
      post_analyzer = PostAnalyzer.new(raw_post_with_favicon, default_topic_id)
      PrettyText.stubs(:cook).returns(raw_post_with_favicon)
      expect(post_analyzer.image_count).to eq(0)
    end

    it "doesn't count thumbnails as images" do
      post_analyzer = PostAnalyzer.new(raw_post_with_thumbnail, default_topic_id)
      PrettyText.stubs(:cook).returns(raw_post_with_thumbnail)
      expect(post_analyzer.image_count).to eq(0)
    end

    it "doesn't count whitelisted images" do
      Post.stubs(:white_listed_image_classes).returns(["classy"])
      PrettyText.stubs(:cook).returns(raw_post_with_two_classy_images)
      post_analyzer = PostAnalyzer.new(raw_post_with_two_classy_images, default_topic_id)
      expect(post_analyzer.image_count).to eq(0)
    end
  end

  describe "link_count" do
    let(:raw_post_one_link_md) { "[sherlock](http://www.bbc.co.uk/programmes/b018ttws)" }
    let(:raw_post_two_links_html) { "<a href='http://discourse.org'>discourse</a> <a href='http://twitter.com'>twitter</a>" }
    let(:raw_post_with_mentions) { "hello @novemberkilo how are you doing?" }

    it "returns 0 links for an empty post" do
      post_analyzer = PostAnalyzer.new("Hello world", nil)
      expect(post_analyzer.link_count).to eq(0)
    end

    it "returns 0 links for a post with mentions" do
      post_analyzer = PostAnalyzer.new(raw_post_with_mentions, default_topic_id)
      expect(post_analyzer.link_count).to eq(0)
    end

    it "returns links with href=''" do
      post_analyzer = PostAnalyzer.new('<a href="">Hello world</a>', nil)
      expect(post_analyzer.link_count).to eq(1)
    end

    it "finds links from markdown" do
      Oneboxer.stubs :onebox
      post_analyzer = PostAnalyzer.new(raw_post_one_link_md, default_topic_id)
      expect(post_analyzer.link_count).to eq(1)
    end

    it "finds links from HTML" do
      post_analyzer = PostAnalyzer.new(raw_post_two_links_html, default_topic_id)
      post_analyzer.cook(raw_post_two_links_html, {})
      expect(post_analyzer.found_oneboxes?).to be(false)
      expect(post_analyzer.link_count).to eq(2)
    end
  end

  describe "raw_mentions" do

    it "returns an empty array with no matches" do
      post_analyzer = PostAnalyzer.new("Hello Jake and Finn!", default_topic_id)
      expect(post_analyzer.raw_mentions).to eq([])
    end

    it "returns lowercase unique versions of the mentions" do
      post_analyzer = PostAnalyzer.new("@Jake @Finn @Jake", default_topic_id)
      expect(post_analyzer.raw_mentions).to eq(['jake', 'finn'])
    end

    it "ignores pre" do
      # note, CommonMark has rules for dealing with HTML, if your paragraph starts with it
      # it will no longer be an "inline" so this means that @Finn in this case would not be a mention
      post_analyzer = PostAnalyzer.new(". <pre>@Jake</pre> @Finn", default_topic_id)
      expect(post_analyzer.raw_mentions).to eq(['finn'])
    end

    it "catches content between pre tags" do
      post_analyzer = PostAnalyzer.new(". <pre>hello</pre> @Finn <pre></pre>", default_topic_id)
      expect(post_analyzer.raw_mentions).to eq(['finn'])
    end

    it "ignores code" do
      post_analyzer = PostAnalyzer.new("@Jake `@Finn`", default_topic_id)
      expect(post_analyzer.raw_mentions).to eq(['jake'])
    end

    it "ignores code in markdown-formatted code blocks" do
      post_analyzer = PostAnalyzer.new("    @Jake @Finn\n@Ryan", default_topic_id)
      expect(post_analyzer.raw_mentions).to eq(['ryan'])
    end

    it "ignores quotes" do
      post_analyzer = PostAnalyzer.new("[quote=\"Evil Trout\"]\n@Jake\n[/quote]\n @Finn", default_topic_id)
      expect(post_analyzer.raw_mentions).to eq(['finn'])
    end

    it "ignores oneboxes" do
      post_analyzer = PostAnalyzer.new("Hello @Jake\n#{url}", default_topic_id)
      post_analyzer.stubs(:cook).returns("<p>Hello <span class=\"mention\">@Jake</span><br><a href=\"https://twitter.com/evil_trout/status/345954894420787200\" class=\"onebox\" target=\"_blank\" rel=\"nofollow noopener\">@Finn</a></p>")
      expect(post_analyzer.raw_mentions).to eq(['jake'])
    end

    it "handles underscore in username" do
      post_analyzer = PostAnalyzer.new("@Jake @Finn @Jake_Old", default_topic_id)
      expect(post_analyzer.raw_mentions).to eq(['jake', 'finn', 'jake_old'])
    end

    it "handles hyphen in groupname" do
      post_analyzer = PostAnalyzer.new("@org-board", default_topic_id)
      expect(post_analyzer.raw_mentions).to eq(['org-board'])
    end

    it "ignores emails" do
      post_analyzer = PostAnalyzer.new("1@test.com 1@best.com @best @not", default_topic_id)
      expect(post_analyzer.raw_mentions).to eq(['best', 'not'])
    end
  end
end
