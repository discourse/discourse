require "rails_helper"

describe UserAnonymizer do

  describe "make_anonymous" do
    let(:admin) { Fabricate(:admin) }
    let(:user) { Fabricate(:user, username: "edward", auth_token: "mysecretauthtoken") }

    subject(:make_anonymous) { described_class.make_anonymous(user, admin) }

    it "changes username" do
      make_anonymous
      expect(user.reload.username).to match(/^anon\d{3,}$/)
    end

    it "changes email address" do
      make_anonymous
      expect(user.reload.email).to eq("#{user.username}@example.com")
    end

    it "turns off all notifications" do
      user.user_option.update_columns(
        email_always: true
      )

      make_anonymous
      user.reload
      expect(user.user_option.email_digests).to eq(false)
      expect(user.user_option.email_private_messages).to eq(false)
      expect(user.user_option.email_direct).to eq(false)
      expect(user.user_option.email_always).to eq(false)
      expect(user.user_option.mailing_list_mode).to eq(false)
    end

    context "Site Settings do not require full name" do
      before do
        SiteSetting.full_name_required = false
      end

      it "resets profile to default values" do
        user.update_attributes( name: "Bibi", date_of_birth: 19.years.ago, title: "Super Star" )

        profile = user.user_profile(true)
        profile.update_attributes( location: "Moose Jaw",
                                   website: "www.bim.com",
                                   bio_raw: "I'm Bibi from Moosejaw. I sing and dance.",
                                   bio_cooked: "I'm Bibi from Moosejaw. I sing and dance.",
                                   profile_background: "http://example.com/bg.jpg",
                                   bio_cooked_version: 2,
                                   card_background: "http://example.com/cb.jpg")

        prev_username = user.username

        make_anonymous
        user.reload

        expect(user.username).not_to eq(prev_username)
        expect(user.name).not_to be_present
        expect(user.date_of_birth).to eq(nil)
        expect(user.title).not_to be_present
        expect(user.auth_token).to eq(nil)

        profile = user.user_profile(true)
        expect(profile.location).to eq(nil)
        expect(profile.website).to eq(nil)
        expect(profile.bio_cooked).to eq(nil)
        expect(profile.profile_background).to eq(nil)
        expect(profile.bio_cooked_version).to eq(nil)
        expect(profile.card_background).to eq(nil)
      end
    end

    context "Site Settings require full name" do
      before do
        SiteSetting.full_name_required = true
      end

      it "changes name to anonymized username" do
        prev_username = user.username

        user.update_attributes( name: "Bibi", date_of_birth: 19.years.ago, title: "Super Star" )

        make_anonymous
        user.reload

        expect(user.name).not_to eq(prev_username)
        expect(user.name).to eq(user.username)
      end
    end

    it "removes the avatar" do
      upload = Fabricate(:upload, user: user)
      user.user_avatar = UserAvatar.new(user_id: user.id, custom_upload_id: upload.id)
      user.uploaded_avatar_id = upload.id # chosen in user preferences
      user.save!
      expect { make_anonymous }.to change { Upload.count }.by(-1)
      user.reload
      expect(user.user_avatar).to eq(nil)
      expect(user.uploaded_avatar_id).to eq(nil)
    end

    it "logs the action" do
      expect { make_anonymous }.to change { UserHistory.count }.by(1)
    end

    it "removes external auth assocations" do
      user.twitter_user_info = TwitterUserInfo.create(user_id: user.id, screen_name: "example", twitter_user_id: "examplel123123")
      user.google_user_info = GoogleUserInfo.create(user_id: user.id, google_user_id: "google@gmail.com")
      user.github_user_info = GithubUserInfo.create(user_id: user.id, screen_name: "example", github_user_id: "examplel123123")
      user.facebook_user_info = FacebookUserInfo.create(user_id: user.id, facebook_user_id: "example")
      user.single_sign_on_record = SingleSignOnRecord.create(user_id: user.id, external_id: "example", last_payload: "looks good")
      user.oauth2_user_info = Oauth2UserInfo.create(user_id: user.id, uid: "example", provider: "example")
      UserOpenId.create(user_id: user.id, email: user.email, url: "http://example.com/openid", active: true)
      make_anonymous
      user.reload
      expect(user.twitter_user_info).to eq(nil)
      expect(user.google_user_info).to eq(nil)
      expect(user.github_user_info).to eq(nil)
      expect(user.facebook_user_info).to eq(nil)
      expect(user.single_sign_on_record).to eq(nil)
      expect(user.oauth2_user_info).to eq(nil)
      expect(user.user_open_ids.count).to eq(0)
    end

    it "removes api key" do
      ApiKey.create(user_id: user.id, key: "123123123")
      expect { make_anonymous }.to change { ApiKey.count }.by(-1)
      user.reload
      expect(user.api_key).to eq(nil)
    end

  end

end
