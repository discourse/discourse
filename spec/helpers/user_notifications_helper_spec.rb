# frozen_string_literal: true

require 'rails_helper'

describe UserNotificationsHelper do
  let(:upload_path) { Discourse.store.upload_path }

  describe '#email_excerpt' do
    let(:paragraphs) { [
      "<p>This is the first paragraph, but you should read more.</p>",
      "<p>And here is its friend, the second paragraph.</p>"
    ] }

    let(:cooked) do
      paragraphs.join("\n")
    end

    let(:post_quote) do
      <<~HTML
        <aside class="quote no-group" data-post="859" data-topic="30">
        <div class="title">
        <div class="quote-controls"></div>
        <img alt width="20" height="20" src="https://example.com/m.png" class="avatar"> modman:</div>
        <blockquote>
        <p>This is a post quote</p>
        </blockquote>
        </aside>
      HTML
    end

    let(:image_paragraph) do
      '<p><img src="//localhost:3000/uploads/b9.png" width="300" height="300"></p>'
    end

    let(:lightbox_image) do
      <<~HTML
        <p><div class="lightbox-wrapper"><a class="lightbox" href="//localhost:3000/uploads/default/original/1X/123456.jpeg" data-download-href="//localhost:3000/uploads/default/123456" title="giant-meteor-2020"><img src="//localhost:3000/uploads/default/original/1X/123456.jpeg" alt="giant-meteor-2020" data-base62-sha1="3jcR88161od6Uthq1ixWKJh2ejp" width="517" height="152" data-small-upload="//localhost:3000/uploads/default/optimized/1X/123456_2_10x10.png"><div class="meta">
        <svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">giant-meteor-2020</span><span class="informations">851×251 44 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg>
        </div></a></div></p>
      HTML
    end

    let(:expected_lightbox_image) do
      '<div class="lightbox-wrapper"><a class="lightbox" href="//localhost:3000/uploads/default/original/1X/123456.jpeg" data-download-href="//localhost:3000/uploads/default/123456" title="giant-meteor-2020"><img src="//localhost:3000/uploads/default/original/1X/123456.jpeg" alt="giant-meteor-2020" data-base62-sha1="3jcR88161od6Uthq1ixWKJh2ejp" width="517" height="152" data-small-upload="//localhost:3000/uploads/default/optimized/1X/123456_2_10x10.png"></a></div>'
    end

    it "can return the first paragraph" do
      SiteSetting.digest_min_excerpt_length = 50
      expect(helper.email_excerpt(cooked)).to eq(paragraphs[0])
    end

    it "can return another paragraph to satisfy digest_min_excerpt_length" do
      SiteSetting.digest_min_excerpt_length = 100
      expect(helper.email_excerpt(cooked)).to eq(paragraphs.join)
    end

    it "doesn't count emoji images" do
      with_emoji = "<p>Hi <img src=\"/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}\" title=\":smile:\" class=\"emoji\" alt=\":smile:\" loading=\"lazy\" width=\"20\" height=\"20\"></p>"
      arg = ([with_emoji] + paragraphs).join("\n")
      SiteSetting.digest_min_excerpt_length = 50
      expect(helper.email_excerpt(arg)).to eq([with_emoji, paragraphs[0]].join)
    end

    it "only counts link text" do
      with_link = "<p>Hi <a href=\"https://really-long.essays.com/essay/number/9000/this-one-is-about-friends-and-got-a-C-minus-in-grade-9\">friends</a>!</p>"
      arg = ([with_link] + paragraphs).join("\n")
      SiteSetting.digest_min_excerpt_length = 50
      expect(helper.email_excerpt(arg)).to eq([with_link, paragraphs[0]].join)
    end

    it "uses user quotes but not post quotes" do
      cooked = <<~HTML
        <p>BEFORE</p>
        <blockquote>
          <p>This is a user quote</p>
        </blockquote>
        <aside class="quote" data-post="3" data-topic="87369">
          <div class="title">A Title</div>
          <blockquote>
            <p>This is a post quote</p>
          </blockquote>
        </aside>
        <p>AFTER</p>
      HTML

      expect(helper.email_excerpt(cooked)).to eq "<p>BEFORE</p><blockquote>\n  <p>This is a user quote</p>\n</blockquote><p>AFTER</p>"
    end

    it "defaults to content after post quote (image w/ no text)" do

      cooked = <<~HTML
        #{post_quote}
        #{image_paragraph}
      HTML
      expect(helper.email_excerpt(cooked)).to eq(image_paragraph)
    end

    it "defaults to content after post quote (onebox)" do
      aside_onebox = '<aside class="onebox wikipedia"><article class="onebox-body"><p>Onebox excerpt here</p></article><div class="onebox-metadata"></div></aside>'
      cooked = <<~HTML
        #{post_quote}
        #{aside_onebox}
      HTML
      expect(helper.email_excerpt(cooked)).to eq(aside_onebox)
    end

    it "defaults to content after post quote (lightbox image w/ no text)" do
      cooked = <<~HTML
        #{post_quote}
        #{lightbox_image}
      HTML
      expect(helper.email_excerpt(cooked)).to eq(expected_lightbox_image)
    end

    it "handles when there's only an image" do
      image_paragraph
      expect(helper.email_excerpt("#{image_paragraph}")).to eq(image_paragraph)
    end

    it "handles when there's only a lightboxed image" do
      expect(helper.email_excerpt("#{lightbox_image}")).to eq(expected_lightbox_image)
    end
  end

  describe '#logo_url' do
    describe 'local store' do
      let(:upload) { Fabricate(:upload, sha1: "somesha1") }

      before do
        SiteSetting.logo = upload
      end

      it 'should return the right URL' do
        expect(helper.logo_url).to eq(
          "http://test.localhost/#{upload_path}/original/1X/somesha1.png"
        )
      end

      describe 'when cdn path is configured' do
        before do
          GlobalSetting.expects(:cdn_url)
            .returns('https://some.localcdn.com')
            .at_least_once
        end

        it 'should return the right URL' do
          expect(helper.logo_url).to eq(
            "https://some.localcdn.com/#{upload_path}/original/1X/somesha1.png"
          )
        end
      end

      describe 'when logo is an SVG' do
        let(:upload) { Fabricate(:upload, extension: "svg") }

        it 'should return nil' do
          expect(helper.logo_url).to eq(nil)
        end
      end
    end

    describe 's3 store' do
      let(:upload) { Fabricate(:upload_s3, sha1: "somesha1") }

      before do
        setup_s3
        SiteSetting.logo = upload
      end

      it 'should return the right URL' do
        expect(helper.logo_url).to eq(
          "http://s3-upload-bucket.s3.dualstack.#{SiteSetting.s3_region}.amazonaws.com/original/1X/somesha1.png"
        )
      end

      describe 'when global cdn path is configured' do
        it 'should return the right url' do
          GlobalSetting.stubs(:cdn_url).returns('https://some.cdn.com/cluster')

          expect(helper.logo_url).to eq(
            "http://s3-upload-bucket.s3.dualstack.#{SiteSetting.s3_region}.amazonaws.com/original/1X/somesha1.png"
          )
        end
      end

      describe 'when cdn path is configured' do
        before do
          SiteSetting.s3_cdn_url = 'https://some.cdn.com'

        end

        it 'should return the right url' do
          expect(helper.logo_url).to eq(
            "https://some.cdn.com/original/1X/somesha1.png"
          )
        end
      end
    end
  end
end
