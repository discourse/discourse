# frozen_string_literal: true

require 'rails_helper'

describe UserProfile do
  it 'is created automatically when a user is created' do
    user = Fabricate(:evil_trout)
    expect(user.user_profile).to be_present
  end

  describe 'rebaking' do
    it 'correctly rebakes bio' do
      user_profile = Fabricate(:evil_trout).user_profile
      user_profile.update_columns(bio_raw: "test", bio_cooked: "broken", bio_cooked_version: nil)

      problems = UserProfile.rebake_old(10)
      expect(problems.length).to eq(0)

      user_profile.reload
      expect(user_profile.bio_cooked).to eq("<p>test</p>")
      expect(user_profile.bio_cooked_version).to eq(UserProfile::BAKED_VERSION)
    end
  end

  describe 'new' do
    let(:user_profile) { UserProfile.new(bio_raw: "test") }

    it 'is not valid without user' do
      expect(user_profile.valid?).to be false
    end

    it 'is is valid with user' do
      user_profile.user = Fabricate.build(:user)
      expect(user_profile.valid?).to be true
    end

    it "doesn't support really long bios" do
      user_profile = Fabricate.build(:user_profile_long)
      expect(user_profile).not_to be_valid
    end

    context "website validation" do
      let(:user_profile) { Fabricate.build(:user_profile, user: Fabricate(:user)) }

      it "should not allow invalid URLs" do
        user_profile.website = "http://https://google.com"
        expect(user_profile).to_not be_valid
      end

      it "validates website domain if user_website_domains_whitelist setting is present" do
        SiteSetting.user_website_domains_whitelist = "discourse.org"

        user_profile.website = "https://google.com"
        expect(user_profile).not_to be_valid

        user_profile.website = "http://discourse.org"
        expect(user_profile).to be_valid
      end

      it "doesn't blow up with an invalid URI" do
        SiteSetting.user_website_domains_whitelist = "discourse.org"

        user_profile.website = 'user - https://forum.example.com/user'
        expect { user_profile.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    describe 'after save' do
      fab!(:user) { Fabricate(:user) }

      before do
        user.user_profile.bio_raw = 'my bio'
        user.user_profile.save
      end

      it 'has cooked bio' do
        expect(user.user_profile.bio_cooked).to be_present
      end

      it 'has bio summary' do
        expect(user.user_profile.bio_summary).to be_present
      end
    end
  end

  describe 'changing bio' do
    fab!(:user) { Fabricate(:user) }

    before do
      user.user_profile.bio_raw = "**turtle power!**"
      user.user_profile.save
      user.user_profile.reload
    end

    it 'should markdown the raw_bio and put it in cooked_bio' do
      expect(user.user_profile.bio_cooked).to eq("<p><strong>turtle power!</strong></p>")
    end
  end

  describe 'bio excerpt emojis' do
    fab!(:user) { Fabricate(:user) }
    fab!(:upload) { Fabricate(:upload) }

    before do
      CustomEmoji.create!(name: 'test', upload: upload)
      Emoji.clear_cache

      user.user_profile.update!(
        bio_raw: "hello :test: :woman_scientist:t5: 🤔"
      )
    end

    it 'supports emoji images' do
      expect(user.user_profile.bio_excerpt(500, keep_emoji_images: true)).to eq("hello <img src=\"#{upload.url}?v=#{Emoji::EMOJI_VERSION}\" title=\":test:\" class=\"emoji emoji-custom\" alt=\":test:\"> <img src=\"/images/emoji/twitter/woman_scientist/5.png?v=#{Emoji::EMOJI_VERSION}\" title=\":woman_scientist:t5:\" class=\"emoji\" alt=\":woman_scientist:t5:\"> <img src=\"/images/emoji/twitter/thinking.png?v=#{Emoji::EMOJI_VERSION}\" title=\":thinking:\" class=\"emoji\" alt=\":thinking:\">")
    end
  end

  describe 'bio link stripping' do

    it 'returns an empty string with no bio' do
      expect(Fabricate.build(:user_profile).bio_excerpt).to be_blank
    end

    context 'with a user that has a link in their bio' do
      let(:user_profile) { Fabricate.build(:user_profile, bio_raw: "I love http://discourse.org") }
      let(:user) do
        user = Fabricate.build(:user, user_profile: user_profile)
        user_profile.user = user
        user
      end

      fab!(:created_user) do
        user = Fabricate(:user)
        user.user_profile.bio_raw = 'I love http://discourse.org'
        user.user_profile.save!
        user
      end

      it 'includes the link as nofollow if the user is not new' do
        user.user_profile.send(:cook)
        expect(user_profile.bio_excerpt).to match_html("I love <a href='http://discourse.org' rel='nofollow noopener'>http://discourse.org</a>")
        expect(user_profile.bio_processed).to match_html("<p>I love <a href=\"http://discourse.org\" rel=\"nofollow noopener\">http://discourse.org</a></p>")
      end

      it 'removes the link if the user is new' do
        user.trust_level = TrustLevel[0]
        user_profile.send(:cook)
        expect(user_profile.bio_excerpt).to match_html("I love http://discourse.org")
        expect(user_profile.bio_processed).to eq("<p>I love http://discourse.org</p>")
      end

      it 'removes the link if the user is suspended' do
        user.suspended_till = 1.month.from_now
        user_profile.send(:cook)
        expect(user_profile.bio_excerpt).to match_html("I love http://discourse.org")
        expect(user_profile.bio_processed).to eq("<p>I love http://discourse.org</p>")
      end

      context 'tl3_links_no_follow is false' do
        before { SiteSetting.tl3_links_no_follow = false }

        it 'includes the link without nofollow if the user is trust level 3 or higher' do
          user.trust_level = TrustLevel[3]
          user_profile.send(:cook)
          expect(user_profile.bio_excerpt).to match_html("I love <a href='http://discourse.org'>http://discourse.org</a>")
          expect(user_profile.bio_processed).to match_html("<p>I love <a href=\"http://discourse.org\">http://discourse.org</a></p>")
        end

        it 'removes nofollow from links in bio when trust level is increased' do
          created_user.change_trust_level!(TrustLevel[3])
          expect(created_user.user_profile.bio_excerpt).to match_html("I love <a href='http://discourse.org'>http://discourse.org</a>")
          expect(created_user.user_profile.bio_processed).to match_html("<p>I love <a href=\"http://discourse.org\">http://discourse.org</a></p>")
        end

        it 'adds nofollow to links in bio when trust level is decreased' do
          created_user.trust_level = TrustLevel[3]
          created_user.save
          created_user.reload
          created_user.change_trust_level!(TrustLevel[2])
          expect(created_user.user_profile.bio_excerpt).to match_html("I love <a href='http://discourse.org' rel='nofollow noopener'>http://discourse.org</a>")
          expect(created_user.user_profile.bio_processed).to match_html("<p>I love <a href=\"http://discourse.org\" rel=\"nofollow noopener\">http://discourse.org</a></p>")
        end
      end

      context 'tl3_links_no_follow is true' do
        before { SiteSetting.tl3_links_no_follow = true }

        it 'includes the link with nofollow if the user is trust level 3 or higher' do
          user.trust_level = TrustLevel[3]
          user_profile.send(:cook)
          expect(user_profile.bio_excerpt).to match_html("I love <a href='http://discourse.org' rel='nofollow noopener'>http://discourse.org</a>")
          expect(user_profile.bio_processed).to match_html("<p>I love <a href=\"http://discourse.org\" rel=\"nofollow noopener\">http://discourse.org</a></p>")
        end
      end
    end
  end

  context '.import_url_for_user' do
    fab!(:user) { Fabricate(:user) }

    before do
      stub_request(:any, "thisfakesomething.something.com")
        .to_return(body: "abc", status: 404, headers: { 'Content-Length' => 3 })
    end

    describe 'when profile_background_url returns an invalid status code' do
      it 'should not do anything' do
        url = "http://thisfakesomething.something.com/"

        UserProfile.import_url_for_user(url, user, is_card_background: false)

        user.reload

        expect(user.profile_background_upload).to eq(nil)
      end
    end

    describe 'when card_background_url returns an invalid status code' do
      it 'should not do anything' do
        url = "http://thisfakesomething.something.com/"

        UserProfile.import_url_for_user(url, user, is_card_background: true)

        user.reload

        expect(user.card_background_upload).to eq(nil)
      end
    end

  end

end
