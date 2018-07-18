require "rails_helper"

describe UserAnonymizer do

  let(:admin) { Fabricate(:admin) }

  describe "event" do
    let(:user) { Fabricate(:user, username: "edward") }
    subject(:make_anonymous) { described_class.make_anonymous(user, admin, anonymize_ip: '2.2.2.2') }

    it "triggers the event" do
      events = DiscourseEvent.track_events do
        make_anonymous
      end

      anon_event = events.detect { |e| e[:event_name] == :user_anonymized }
      expect(anon_event).to be_present
      params_hash = anon_event[:params][0]

      expect(params_hash[:user]).to eq(user)
      expect(params_hash[:opts][:anonymize_ip]).to eq('2.2.2.2')
    end
  end

  describe "make_anonymous" do
    let(:original_email) { "edward@example.net" }
    let(:user) { Fabricate(:user, username: "edward", email: original_email) }
    let(:another_user) { Fabricate(:evil_trout) }
    subject(:make_anonymous) { described_class.make_anonymous(user, admin) }

    it "changes username" do
      make_anonymous
      expect(user.reload.username).to match(/^anon\d{3,}$/)
    end

    it "changes email address" do
      make_anonymous
      expect(user.reload.email).to eq("#{user.username}@anonymized.invalid")
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
        user.update_attributes(name: "Bibi", date_of_birth: 19.years.ago, title: "Super Star")

        profile = user.reload.user_profile
        profile.update_attributes(location: "Moose Jaw",
                                  website: "www.bim.com",
                                  bio_raw: "I'm Bibi from Moosejaw. I sing and dance.",
                                  bio_cooked: "I'm Bibi from Moosejaw. I sing and dance.",
                                  profile_background: "http://example.com/bg.jpg",
                                  bio_cooked_version: 2,
                                  card_background: "http://example.com/cb.jpg")

        prev_username = user.username

        UserAuthToken.generate!(user_id: user.id)

        make_anonymous
        user.reload

        expect(user.username).not_to eq(prev_username)
        expect(user.name).not_to be_present
        expect(user.date_of_birth).to eq(nil)
        expect(user.title).not_to be_present
        expect(user.user_auth_tokens.count).to eq(0)

        profile = user.reload.user_profile
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

        user.update_attributes(name: "Bibi", date_of_birth: 19.years.ago, title: "Super Star")

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

    it "updates the avatar in posts" do
      SiteSetting.queue_jobs = false
      upload = Fabricate(:upload, user: user)
      user.user_avatar = UserAvatar.new(user_id: user.id, custom_upload_id: upload.id)
      user.uploaded_avatar_id = upload.id # chosen in user preferences
      user.save!

      topic = Fabricate(:topic, user: user)
      quoted_post = create_post(user: user, topic: topic, post_number: 1, raw: "quoted post")
      post = create_post(raw: <<~RAW)
        Lorem ipsum

        [quote="#{quoted_post.username}, post:1, topic:#{quoted_post.topic.id}"]
        quoted post
        [/quote]
      RAW

      old_avatar_url = user.avatar_template.gsub("{size}", "40")
      expect(post.cooked).to include(old_avatar_url)

      make_anonymous
      post.reload
      new_avatar_url = user.reload.avatar_template.gsub("{size}", "40")

      expect(post.cooked).to_not include(old_avatar_url)
      expect(post.cooked).to include(new_avatar_url)
    end

    it "logs the action with the original details" do
      SiteSetting.log_anonymizer_details = true
      helper = UserAnonymizer.new(user, admin)
      orig_email = user.email
      orig_username = user.username
      helper.make_anonymous

      history = helper.user_history
      expect(history).to be_present
      expect(history.email).to eq(orig_email)
      expect(history.details).to match(orig_username)
    end

    it "logs the action without the original details" do
      SiteSetting.log_anonymizer_details = false
      helper = UserAnonymizer.new(user, admin)
      orig_email = user.email
      orig_username = user.username
      helper.make_anonymous

      history = helper.user_history
      expect(history).to be_present
      expect(history.email).not_to eq(orig_email)
      expect(history.details).not_to match(orig_username)
    end

    it "removes external auth assocations" do
      user.twitter_user_info = TwitterUserInfo.create(user_id: user.id, screen_name: "example", twitter_user_id: "examplel123123")
      user.google_user_info = GoogleUserInfo.create(user_id: user.id, google_user_id: "google@gmail.com")
      user.github_user_info = GithubUserInfo.create(user_id: user.id, screen_name: "example", github_user_id: "examplel123123")
      user.facebook_user_info = FacebookUserInfo.create(user_id: user.id, facebook_user_id: "example")
      user.single_sign_on_record = SingleSignOnRecord.create(user_id: user.id, external_id: "example", last_payload: "looks good")
      user.oauth2_user_info = Oauth2UserInfo.create(user_id: user.id, uid: "example", provider: "example")
      user.instagram_user_info = InstagramUserInfo.create(user_id: user.id, screen_name: "example", instagram_user_id: "examplel123123")
      UserOpenId.create(user_id: user.id, email: user.email, url: "http://example.com/openid", active: true)
      make_anonymous
      user.reload
      expect(user.twitter_user_info).to eq(nil)
      expect(user.google_user_info).to eq(nil)
      expect(user.github_user_info).to eq(nil)
      expect(user.facebook_user_info).to eq(nil)
      expect(user.single_sign_on_record).to eq(nil)
      expect(user.oauth2_user_info).to eq(nil)
      expect(user.instagram_user_info).to eq(nil)
      expect(user.user_open_ids.count).to eq(0)
    end

    it "removes api key" do
      ApiKey.create(user_id: user.id, key: "123123123")
      expect { make_anonymous }.to change { ApiKey.count }.by(-1)
      user.reload
      expect(user.api_key).to eq(nil)
    end

    context "executes job" do
      before do
        SiteSetting.queue_jobs = false
      end

      it "removes invites" do
        Fabricate(:invite, user: user)
        Fabricate(:invite, user: another_user)

        expect { make_anonymous }.to change { Invite.count }.by(-1)
        expect(Invite.where(user_id: user.id).count).to eq(0)
      end

      it "removes email tokens" do
        Fabricate(:email_token, user: user)
        Fabricate(:email_token, user: another_user)

        expect { make_anonymous }.to change { EmailToken.count }.by(-1)
        expect(EmailToken.where(user_id: user.id).count).to eq(0)
      end

      it "removes email log entries" do
        Fabricate(:email_log, user: user)
        Fabricate(:email_log, user: another_user)

        expect { make_anonymous }.to change { EmailLog.count }.by(-1)
        expect(EmailLog.where(user_id: user.id).count).to eq(0)
      end

      it "removes incoming emails" do
        Fabricate(:incoming_email, user: user, from_address: user.email)
        Fabricate(:incoming_email, from_address: user.email, error: "Some error")
        Fabricate(:incoming_email, user: another_user, from_address: another_user.email)

        expect { make_anonymous }.to change { IncomingEmail.count }.by(-2)
        expect(IncomingEmail.where(user_id: user.id).count).to eq(0)
        expect(IncomingEmail.where(from_address: original_email).count).to eq(0)
      end

      it "removes raw email from posts" do
        post1 = Fabricate(:post, user: user, via_email: true, raw_email: "raw email from user")
        post2 = Fabricate(:post, user: another_user, via_email: true, raw_email: "raw email from another user")

        make_anonymous

        expect(post1.reload).to have_attributes(via_email: true, raw_email: nil)
        expect(post2.reload).to have_attributes(via_email: true, raw_email: "raw email from another user")
      end

      it "does not delete profile views" do
        UserProfileView.add(user.id, '127.0.0.1', another_user.id, Time.now, true)
        expect { make_anonymous }.to_not change { UserProfileView.count }
      end
    end
  end

  describe "anonymize_ip" do
    let(:old_ip) { "1.2.3.4" }
    let(:anon_ip) { "0.0.0.0" }
    let(:user) { Fabricate(:user, ip_address: old_ip, registration_ip_address: old_ip) }
    let(:post) { Fabricate(:post) }
    let(:topic) { post.topic }

    it "doesn't anonymize ips by default" do
      UserAnonymizer.make_anonymous(user, admin)
      expect(user.ip_address).to eq(old_ip)
    end

    it "is called if you pass an option" do
      UserAnonymizer.make_anonymous(user, admin, anonymize_ip: anon_ip)
      user.reload
      expect(user.ip_address).to eq(anon_ip)
    end

    it "exhaustively replaces all user ips" do
      SiteSetting.queue_jobs = false
      link = IncomingLink.create!(current_user_id: user.id, ip_address: old_ip, post_id: post.id)

      screened_email = ScreenedEmail.create!(email: user.email, ip_address: old_ip)

      search_log = SearchLog.create!(
        term: 'wat',
        search_type: SearchLog.search_types[:header],
        user_id: user.id,
        ip_address: old_ip
      )

      topic_link = TopicLink.create!(
        user_id: admin.id,
        topic_id: topic.id,
        url: 'https://discourse.org',
        domain: 'discourse.org'
      )

      topic_link_click = TopicLinkClick.create!(
        topic_link_id: topic_link.id,
        user_id: user.id,
        ip_address: old_ip
      )

      user_profile_view = UserProfileView.create!(
        user_id: user.id,
        user_profile_id: admin.user_profile.id,
        ip_address: old_ip,
        viewed_at: Time.now
      )

      TopicViewItem.create!(topic_id: topic.id, user_id: user.id, ip_address: old_ip, viewed_at: Time.now)
      delete_history = StaffActionLogger.new(admin).log_user_deletion(user)
      user_history = StaffActionLogger.new(user).log_backup_create

      UserAnonymizer.make_anonymous(user, admin, anonymize_ip: anon_ip)
      expect(user.registration_ip_address).to eq(anon_ip)
      expect(link.reload.ip_address).to eq(anon_ip)
      expect(screened_email.reload.ip_address).to eq(anon_ip)
      expect(search_log.reload.ip_address).to eq(anon_ip)
      expect(topic_link_click.reload.ip_address).to eq(anon_ip)
      topic_view = TopicViewItem.where(topic_id: topic.id, user_id: user.id).first
      expect(topic_view.ip_address).to eq(anon_ip)
      expect(delete_history.reload.ip_address).to eq(anon_ip)
      expect(user_history.reload.ip_address).to eq(anon_ip)
      expect(user_profile_view.reload.ip_address).to eq(anon_ip)
    end

  end

end
