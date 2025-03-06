# frozen_string_literal: true
RSpec.describe InlineUploads do
  before { set_cdn_url "https://awesome.com" }

  describe ".process" do
    context "with local uploads" do
      fab!(:upload)
      fab!(:upload2) { Fabricate(:upload) }
      fab!(:upload3) { Fabricate(:upload) }

      it "should not correct existing inline uploads" do
        md = <<~MD
        ![test](#{upload.short_url})haha
        [test]#{upload.short_url}
        MD

        expect(InlineUploads.process(md)).to eq(md)

        md = <<~MD
        ![test](#{upload.short_url})
        [test|attachment](#{upload.short_url})
        MD

        expect(InlineUploads.process(md)).to eq(md)
      end

      it "should not escape existing content" do
        md = "1 > 2"

        expect(InlineUploads.process(md)).to eq(md)
      end

      it "should not escape invalid HTML tags" do
        md = "<x>.<y>"

        expect(InlineUploads.process(md)).to eq(md)
      end

      it "should work with invalid img tags" do
        md = <<~MD
        <img src="#{upload.url}">

        This is an invalid `<img ...>` tag
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        <img src="#{upload.short_url}">

        This is an invalid `<img ...>` tag
        MD

        md = '<img data-id="<>">'
        expect(InlineUploads.process(md)).to eq(md)
      end

      it "should not correct code blocks" do
        md = "`<a class=\"attachment\" href=\"#{upload2.url}\">In Code Block</a>`"

        expect(InlineUploads.process(md)).to eq(md)

        md = "    <a class=\"attachment\" href=\"#{upload2.url}\">In Code Block</a>"

        expect(InlineUploads.process(md)).to eq(md)
      end

      it "should not correct invalid links in quotes" do
        post = Fabricate(:post)
        user = Fabricate(:user)

        md = <<~MD
        [quote="#{user.username}, post:#{post.post_number}, topic:#{post.topic.id}"]
        <img src="#{upload.url}"
        someothertext#{upload2.url}someothertext

        <img src="#{upload.url}"

        sometext#{upload2.url}sometext

        #{upload3.url}

        #{Discourse.base_url}#{upload3.url}
        [/quote]

        <img src="#{upload2.url}">
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        [quote="#{user.username}, post:#{post.post_number}, topic:#{post.topic.id}"]
        <img src="#{upload.url}"
        someothertext#{upload2.url}someothertext

        <img src="#{upload.url}"

        sometext#{upload2.url}sometext

        #{upload3.url}

        ![](#{upload3.short_url})
        [/quote]

        <img src="#{upload2.short_url}">
        MD
      end

      it "should correct links in quotes" do
        post = Fabricate(:post)
        user = Fabricate(:user)

        md = <<~MD
        [quote="#{user.username}, post:#{post.post_number}, topic:#{post.topic.id}"]
        some quote

        #{Discourse.base_url}#{upload3.url}

        ![](#{upload.url})
        [/quote]
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        [quote="#{user.username}, post:#{post.post_number}, topic:#{post.topic.id}"]
        some quote

        ![](#{upload3.short_url})

        ![](#{upload.short_url})
        [/quote]
        MD
      end

      it "should correct markdown linked images" do
        md = <<~MD
        [![](#{upload.url})](https://somelink.com)

        [![some test](#{upload2.url})](https://somelink.com)
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        [![](#{upload.short_url})](https://somelink.com)

        [![some test](#{upload2.short_url})](https://somelink.com)
        MD
      end

      it "should correct markdown images with title" do
        md = <<~MD
        ![](#{upload.url} "some alt")
        ![testing](#{upload2.url}  'some alt'  )
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        ![](#{upload.short_url} "some alt")
        ![testing](#{upload2.short_url}  'some alt'  )
        MD
      end

      it "should correct bbcode img URLs to the short version" do
        md = <<~MD
        [img]http://some.external.img[/img]
        [img]#{upload.url}[/img]
        <img src="#{upload3.url}">

        [img]
        #{upload2.url}
        [/img]

        [img]#{upload.url}[/img][img]#{upload2.url}[/img]
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        [img]http://some.external.img[/img]
        ![](#{upload.short_url})
        <img src="#{upload3.short_url}">

        ![](#{upload2.short_url})

        ![](#{upload.short_url})![](#{upload2.short_url})
        MD
      end

      it "should correct markdown references" do
        md = <<~MD
        [link3][3]

        [3]: #{Discourse.base_url}#{upload2.url}

        This is a [link1][1] test [link2][2] something

        <img src="#{upload.url}">

        [1]: #{Discourse.base_url}#{upload.url}
        [2]: #{Discourse.base_url.sub("http://", "https://")}#{upload2.url}
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        [link3][3]

        [3]: #{Discourse.base_url}#{upload2.short_path}

        This is a [link1][1] test [link2][2] something

        <img src="#{upload.short_url}">

        [1]: #{Discourse.base_url}#{upload.short_path}
        [2]: #{Discourse.base_url}#{upload2.short_path}
        MD
      end

      it "should correct html and markdown uppercase references" do
        md = <<~MD
        [IMG]#{upload.url}[/IMG]
        <IMG src="#{upload2.url}" />
        <A class="attachment" href="#{upload3.url}">Text</A>
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        ![](#{upload.short_url})
        <img src="#{upload2.short_url}">
        [Text|attachment](#{upload3.short_url})
        MD
      end

      it "should correct image URLs with v parameters" do
        md = <<~MD
        <img src="#{upload.url}?v=1">

        <img src="#{Discourse.base_url}#{upload.url}?v=2">

        <img src="#{GlobalSetting.cdn_url}#{upload.url}?v=3">

        #{Discourse.base_url}#{upload.url}?v=45

        #{GlobalSetting.cdn_url}#{upload.url}?v=999
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        <img src="#{upload.short_url}">

        <img src="#{upload.short_url}">

        <img src="#{upload.short_url}">

        ![](#{upload.short_url})

        ![](#{upload.short_url})
        MD
      end

      context "with subfolder" do
        before { set_subfolder "/community" }

        it "should correct subfolder images" do
          md = <<~MD
            <img src="/community#{upload.url}">

            #{Discourse.base_url}#{upload.url}
          MD

          expect(InlineUploads.process(md)).to eq(<<~MD)
            <img src="#{upload.short_url}">

            ![](#{upload.short_url})
          MD
        end
      end

      it "should correct raw image URLs to the short url and paths" do
        md = <<~MD
        #{Discourse.base_url}#{upload.url}

        #{Discourse.base_url}#{upload.url} #{Discourse.base_url}#{upload2.url}

        #{Discourse.base_url}#{upload3.url}

        #{GlobalSetting.cdn_url}#{upload3.url}
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        ![](#{upload.short_url})

        #{Discourse.base_url}#{upload.short_path} #{Discourse.base_url}#{upload2.short_path}

        ![](#{upload3.short_url})

        ![](#{upload3.short_url})
        MD
      end

      it "should correct non image URLs to the short url" do
        SiteSetting.authorized_extensions = "mp4"
        upload = Fabricate(:video_upload)
        upload2 = Fabricate(:video_upload)

        md = <<~MD
        #{Discourse.base_url}#{upload.url}

        #{Discourse.base_url}#{upload.url} #{Discourse.base_url}#{upload2.url}

        #{GlobalSetting.cdn_url}#{upload2.url}
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        #{Discourse.base_url}#{upload.short_path}

        #{Discourse.base_url}#{upload.short_path} #{Discourse.base_url}#{upload2.short_path}

        #{Discourse.base_url}#{upload2.short_path}
        MD
      end

      it "should correct img tags with uppercase upload extension" do
        md = <<~MD
        test<img src="#{upload.url.sub(".png", ".PNG")}">
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        test<img src="#{upload.short_url}">
        MD
      end

      it "should correct image URLs that follows an image md" do
        md = <<~MD
        ![image|690x290](#{upload.short_url})#{Discourse.base_url}#{upload2.url}

        <#{Discourse.base_url}#{upload2.url}>
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        ![image|690x290](#{upload.short_url})#{Discourse.base_url}#{upload2.short_path}

        <#{Discourse.base_url}#{upload2.short_path}>
        MD
      end

      it "should correct image URLs to the short version" do
        md = <<~MD
        ![image|690x290](#{upload.short_url})

        ![IMAge|690x190,60%](#{upload.short_url})

        ![image](#{upload2.url})
        ![image|100x100](#{upload3.url})

        <img src="#{Discourse.base_url}#{upload.url}" alt="some image" title="some title" />
        <img src="#{Discourse.base_url}#{upload2.url}" alt="some image"><img src="#{Discourse.base_url}#{upload3.url}" alt="some image">

        #{Discourse.base_url}#{upload3.url} #{Discourse.base_url}#{upload3.url}

        <img src="#{upload.url}" width="5" height="4">
        <img src="#{upload.url}" width="5px" height="auto">

        `<img src="#{upload.url}" alt="image inside code quotes">`

        ```
        <img src="#{upload.url}" alt="image inside code fences">
        ```

            <img src="#{upload.url}" alt="image inside code block">
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        ![image|690x290](#{upload.short_url})

        ![IMAge|690x190,60%](#{upload.short_url})

        ![image](#{upload2.short_url})
        ![image|100x100](#{upload3.short_url})

        <img src="#{upload.short_url}" alt="some image" title="some title">
        <img src="#{upload2.short_url}" alt="some image"><img src="#{upload3.short_url}" alt="some image">

        #{Discourse.base_url}#{upload3.short_path} #{Discourse.base_url}#{upload3.short_path}

        <img src="#{upload.short_url}" width="5" height="4">
        <img src="#{upload.short_url}" width="5px" height="auto">

        `<img src="#{upload.url}" alt="image inside code quotes">`

        ```
        <img src="#{upload.url}" alt="image inside code fences">
        ```

            <img src="#{upload.url}" alt="image inside code block">
        MD
      end

      it "should not replace identical markdown in code blocks", skip: "Known issue" do
        md = <<~MD
        `![image|690x290](#{upload.url})`
        ![image|690x290](#{upload.url})
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        `![image|690x290](#{upload.url})`
        ![image|690x290](#{upload.short_url})
        MD
      end

      it "should not be affected by an emoji" do
        CustomEmoji.create!(name: "test", upload: upload3)
        Emoji.clear_cache

        md = <<~MD
        :test:

        ![image|690x290](#{upload.url})
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        :test:

        ![image|690x290](#{upload.short_url})
        MD
      end

      it "should correctly update images sources within anchor tags with indentation" do
        md = <<~MD
        <h1></h1>
                        <a href="http://somelink.com">
                          <img src="#{upload2.url}" alt="test" width="500" height="500">
                        </a>

                        <a href="http://somelink.com">
                          <img src="#{upload2.url}" alt="test" width="500" height="500">
                        </a>
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        <h1></h1>
                        <a href="http://somelink.com">
                          <img src="#{upload2.short_url}" alt="test" width="500" height="500">
                        </a>

                        <a href="http://somelink.com">
                          <img src="#{upload2.url}" alt="test" width="500" height="500">
                        </a>
        MD

        md =
          "<h1></h1>\r\n<a href=\"http://somelink.com\">\r\n        <img src=\"#{upload.url}\" alt=\"test\" width=\"500\" height=\"500\">\r\n</a>"

        expect(InlineUploads.process(md)).to eq(
          "<h1></h1>\r\n<a href=\"http://somelink.com\">\r\n        <img src=\"#{upload.short_url}\" alt=\"test\" width=\"500\" height=\"500\">\r\n</a>",
        )
      end

      it "should correctly update image sources within anchor or paragraph tags" do
        md = <<~MD
        <a href="http://somelink.com">
          <img src="#{upload.url}" alt="test" width="500" height="500">
        </a>

        <p>
          <img src="#{upload2.url}" alt="test">
        </p>

        <a href="http://somelink.com"><img src="#{upload3.url}" alt="test" width="500" height="500"></a>

        <a href="http://somelink.com">  <img src="#{upload.url}" alt="test" width="500" height="500">  </a>

        <a href="http://somelink.com">


        <img src="#{upload.url}" alt="test" width="500" height="500">

        </a>

        <p>Test <img src="#{upload2.url}" alt="test" width="500" height="500"></p>

        <hr/>
        <img src="#{upload2.url}" alt="test" width="500" height="500">
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        <a href="http://somelink.com">
          <img src="#{upload.short_url}" alt="test" width="500" height="500">
        </a>

        <p>
          <img src="#{upload2.short_url}" alt="test">
        </p>

        <a href="http://somelink.com"><img src="#{upload3.short_url}" alt="test" width="500" height="500"></a>

        <a href="http://somelink.com">  <img src="#{upload.short_url}" alt="test" width="500" height="500">  </a>

        <a href="http://somelink.com">


        <img src="#{upload.short_url}" alt="test" width="500" height="500">

        </a>

        <p>Test <img src="#{upload2.short_url}" alt="test" width="500" height="500"></p>

        <hr/>
        <img src="#{upload2.short_url}" alt="test" width="500" height="500">
        MD
      end

      it "should not be affected by fake HTML tags" do
        md = <<~MD
        ```
        This is some <img src=" and <a href="
        ```

        <img src="#{upload.url}" alt="test">

        <img src="#{upload2.url}" alt="test" height="150<img">

        > some quote

        <a class="attachment" href="#{upload2.url}">test2</a>
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        ```
        This is some <img src=" and <a href="
        ```

        <img src="#{upload.short_url}" alt="test">

        <img src="#{upload2.short_url}" alt="test" height="150<img">

        > some quote

        [test2|attachment](#{upload2.short_url})
        MD
      end

      it "should not be affected by an external or invalid links" do
        md = <<~MD
        <a id="test">invalid</a>

        [test]("https://this.is.some.external.link")

        <a href="https://some.external.com/link">test</a>

        <a class="attachment" href="#{upload2.url}">test2</a>
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        <a id="test">invalid</a>

        [test]("https://this.is.some.external.link")

        <a href="https://some.external.com/link">test</a>

        [test2|attachment](#{upload2.short_url})
        MD
      end

      it "should correct attachment URLS to the short version when raw contains inline image" do
        md = <<~MD
        ![image](#{upload.short_url}) ![image](#{upload.short_url})

        [some complicated.doc %50](#{upload3.url})

        <a class="attachment" href="#{upload2.url}">test2</a>
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        ![image](#{upload.short_url}) ![image](#{upload.short_url})

        [some complicated.doc %50](#{upload3.short_url})

        [test2|attachment](#{upload2.short_url})
        MD
      end

      it "should correct attachment URLs to the short version" do
        md = <<~MD
        <a class="attachment" href="#{upload.url}">
          this
          is
          some
          attachment

        </a>

        - <a class="attachment" href="#{upload.url}">test2</a>
          - <a class="attachment" href="#{upload2.url}">test2</a>
            - <a class="attachment" href="#{upload3.url}">test2</a>

        <a class="test attachment" href="#{upload.url}">test3</a>
        <a class="test attachment" href="#{upload2.url}">test3</a><a class="test attachment" href="#{upload3.url}">test3</a>

        <a class="test attachment" href="#{upload3.url}">This is some _test_ here</a>
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        [this is some attachment|attachment](#{upload.short_url})

        - [test2|attachment](#{upload.short_url})
          - [test2|attachment](#{upload2.short_url})
            - [test2|attachment](#{upload3.short_url})

        [test3|attachment](#{upload.short_url})
        [test3|attachment](#{upload2.short_url})[test3|attachment](#{upload3.short_url})

        [This is some _test_ here|attachment](#{upload3.short_url})
        MD
      end

      it "should correct full upload url to the shorter version" do
        md = <<~MD
        Some random text

        ![test](#{upload.short_url})
        [test|attachment](#{upload.short_url})

        <a class="test attachment" href="#{upload.url}">
          test
        </a>

        `<a class="attachment" href="#{upload2.url}">In Code Block</a>`

            <a class="attachment" href="#{upload3.url}">In Code Block</a>

        <a href="#{upload.url}">newtest</a>
        <a href="#{Discourse.base_url_no_prefix}#{upload.url}">newtest</a>

        <a href="https://somerandomesite.com#{upload.url}">test</a>
        <a class="attachment" href="https://somerandom.com/url">test</a>
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        Some random text

        ![test](#{upload.short_url})
        [test|attachment](#{upload.short_url})

        [test|attachment](#{upload.short_url})

        `<a class="attachment" href="#{upload2.url}">In Code Block</a>`

            <a class="attachment" href="#{upload3.url}">In Code Block</a>

        [newtest](#{upload.short_url})
        [newtest](#{upload.short_url})

        <a href="https://somerandomesite.com#{upload.url}">test</a>
        <a class="attachment" href="https://somerandom.com/url">test</a>
        MD
      end

      it "accepts a block that yields when link does not match an upload in the db" do
        url = "#{Discourse.base_url}#{upload.url}"

        md = <<~MD
        <img src="#{url}" alt="some image">
        <img src="#{upload2.url}" alt="some image">
        MD

        upload.destroy!

        InlineUploads.process(md, on_missing: lambda { |link| expect(link).to eq(url) })
      end
    end

    context "with s3 uploads" do
      let(:upload) { Fabricate(:upload_s3) }
      let(:upload2) { Fabricate(:upload_s3) }
      let(:upload3) { Fabricate(:upload) }

      before do
        upload3
        setup_s3
        SiteSetting.s3_cdn_url = "https://s3.cdn.com"
      end

      it "should correct image URLs to the short version" do
        md = <<~MD
        #{upload.url}
        <img src="#{upload.url}" alt="some image">
        test<img src="#{upload2.url}" alt="some image">test
        <img src="#{URI.join(SiteSetting.s3_cdn_url, URI.parse(upload2.url).path)}" alt="some image">
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        ![](#{upload.short_url})
        <img src="#{upload.short_url}" alt="some image">
        test<img src="#{upload2.short_url}" alt="some image">test
        <img src="#{upload2.short_url}" alt="some image">
        MD
      end

      it "should correct markdown references" do
        md = <<~MD
        This is a [some reference] something

        [some reference]: https:#{upload.url}
        MD

        expect(InlineUploads.process(md)).to eq(<<~MD)
        This is a [some reference] something

        [some reference]: #{Discourse.base_url}#{upload.short_path}
        MD
      end
    end
  end

  describe ".match_md_inline_img" do
    it "matches URLs with various characters" do
      md = <<~MD
      ![test](https://some-site.com/a_test?q=1&b=hello%20there)
      MD

      url = nil
      InlineUploads.match_md_inline_img(md, external_src: true) { |_match, src| url = src }

      expect(url).to eq("https://some-site.com/a_test?q=1&b=hello%20there")
    end
  end

  describe ".replace_hotlinked_image_urls" do
    context "when raw has an image URL" do
      fab!(:image_upload)
      it "replaces URL with image markdown and uses filename as alt" do
        origin = "http://foo.bar/#{image_upload.original_filename}"
        raw =
          InlineUploads.replace_hotlinked_image_urls(raw: "look at this:\n#{origin}") do |match_src|
            expect(match_src).to eq(origin)
            image_upload
          end

        expect(raw).to eq("look at this:\n![logo](#{image_upload.short_url})")
      end
    end
    context "when raw has an image URL with a square bracket in filename" do
      let!(:image_upload) { Fabricate(:image_upload, original_filename: "image]1.jpg") }
      it "does not make broken markdown" do
        origin = "http://foo.bar/#{image_upload.original_filename}"
        raw =
          InlineUploads.replace_hotlinked_image_urls(raw: "look at this:\n#{origin}") do |match_src|
            expect(match_src).to eq(origin)
            image_upload
          end

        expect(raw).to eq("look at this:\n![image1](#{image_upload.short_url})")
      end
    end
  end
end
