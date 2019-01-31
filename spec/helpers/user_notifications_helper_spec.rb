require 'rails_helper'

describe UserNotificationsHelper do
  describe '#email_excerpt' do
    let(:paragraphs) { [
      "<p>This is the first paragraph, but you should read more.</p>",
      "<p>And here is its friend, the second paragraph.</p>"
    ] }

    let(:cooked) do
      paragraphs.join("\n")
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
      with_emoji = "<p>Hi <img src=\"/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}\" title=\":smile:\" class=\"emoji\" alt=\":smile:\"></p>"
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
  end

  describe '#logo_url' do
    describe 'local store' do
      let(:upload) { Fabricate(:upload, sha1: "somesha1") }

      before do
        SiteSetting.logo = upload
      end

      it 'should return the right URL' do
        expect(helper.logo_url).to eq(
          "http://test.localhost/uploads/default/original/1X/somesha1.png"
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
            "https://some.localcdn.com/uploads/default/original/1X/somesha1.png"
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
        SiteSetting.enable_s3_uploads = true
        SiteSetting.s3_upload_bucket = "s3-upload-bucket"
        SiteSetting.s3_access_key_id = "some key"
        SiteSetting.s3_secret_access_key = "some secret key"
        SiteSetting.logo = upload
      end

      it 'should return the right URL' do
        expect(helper.logo_url).to eq(
          "http://s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com/original/1X/somesha1.png"
        )
      end

      describe 'when global cdn path is configured' do
        it 'should return the right url' do
          GlobalSetting.stubs(:cdn_url).returns('https://some.cdn.com/cluster')

          expect(helper.logo_url).to eq(
            "http://s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com/original/1X/somesha1.png"
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
