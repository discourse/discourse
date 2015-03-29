require "spec_helper"

describe UserAnonymizer do

  describe "make_anonymous" do
    let(:admin) { Fabricate(:admin) }
    let(:user) { Fabricate(:user, username: "edward") }

    subject(:make_anonymous) { described_class.make_anonymous(user, admin) }

    it "changes username" do
      make_anonymous
      user.reload.username.should =~ /^anon\d{3,}$/
    end

    it "changes email address" do
      make_anonymous
      user.reload.email.should == "#{user.username}@example.com"
    end

    it "turns off all notifications" do
      make_anonymous
      user.reload
      user.email_digests.should == false
      user.email_private_messages.should == false
      user.email_direct.should == false
      user.email_always.should == false
      user.mailing_list_mode.should == false
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
      make_anonymous
      user.reload

      user.name.should_not be_present
      user.date_of_birth.should == nil
      user.title.should_not be_present

      profile = user.user_profile(true)
      profile.location.should == nil
      profile.website.should == nil
      profile.bio_cooked.should == nil
      profile.profile_background.should == nil
      profile.bio_cooked_version.should == nil
      profile.card_background.should == nil
    end

    it "removes the avatar" do
      upload = Fabricate(:upload, user: user)
      user.user_avatar = UserAvatar.new(user_id: user.id, custom_upload_id: upload.id)
      user.save!
      expect { make_anonymous }.to change { Upload.count }.by(-1)
      user.reload
      user.user_avatar.should == nil
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
      user.twitter_user_info.should == nil
      user.google_user_info.should == nil
      user.github_user_info.should == nil
      user.facebook_user_info.should == nil
      user.single_sign_on_record.should == nil
      user.oauth2_user_info.should == nil
      user.user_open_ids.count.should == 0
    end

    it "removes api key" do
      ApiKey.create(user_id: user.id, key: "123123123")
      expect { make_anonymous }.to change { ApiKey.count }.by(-1)
      user.reload
      user.api_key.should == nil
    end

  end

end
