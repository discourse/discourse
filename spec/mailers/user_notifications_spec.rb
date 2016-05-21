require "rails_helper"

describe UserNotifications do

  let(:user) { Fabricate(:admin) }

  describe "#get_context_posts" do
    it "does not include hidden/deleted/user_deleted posts in context" do
      post1 = create_post
      _post2 = Fabricate(:post, topic: post1.topic, deleted_at: 1.day.ago)
      _post3 = Fabricate(:post, topic: post1.topic, user_deleted: true)
      _post4 = Fabricate(:post, topic: post1.topic, hidden: true)
      _post5 = Fabricate(:post, topic: post1.topic, post_type: Post.types[:moderator_action])
      _post6 = Fabricate(:post, topic: post1.topic, post_type: Post.types[:small_action])
      _post7 = Fabricate(:post, topic: post1.topic, post_type: Post.types[:whisper])
      last  = Fabricate(:post, topic: post1.topic)

      post1.user.user_option.email_previous_replies = UserOption.previous_replies_type[:always]

      # default is only post #1
      expect(UserNotifications.get_context_posts(last, nil, post1.user).count).to eq(1)
      # staff members can also see the whisper
      moderator = build(:moderator)
      moderator.user_option = UserOption.new
      moderator.user_option.email_previous_replies = UserOption.previous_replies_type[:always]
      tu = TopicUser.new(topic: post1.topic, user: moderator)
      expect(UserNotifications.get_context_posts(last, tu, tu.user).count).to eq(2)
    end

    it "allows users to control context" do
      post1 = create_post
      _post2  = Fabricate(:post, topic: post1.topic)
      post3  = Fabricate(:post, topic: post1.topic)

      user = Fabricate(:user)
      TopicUser.change(user.id, post1.topic_id, last_emailed_post_number: 1)
      topic_user = TopicUser.find_by(user_id: user.id, topic_id: post1.topic_id)
      # to avoid reloads after update_columns
      user = topic_user.user
      user.user_option.update_columns(email_previous_replies: UserOption.previous_replies_type[:unless_emailed])

      expect(UserNotifications.get_context_posts(post3, topic_user, user).count).to eq(1)

      user.user_option.update_columns(email_previous_replies: UserOption.previous_replies_type[:never])
      expect(UserNotifications.get_context_posts(post3, topic_user, user).count).to eq(0)

      user.user_option.update_columns(email_previous_replies: UserOption.previous_replies_type[:always])
      expect(UserNotifications.get_context_posts(post3, topic_user, user).count).to eq(2)

    end
  end

  describe ".signup" do

    subject { UserNotifications.signup(user) }

    it "works" do
      expect(subject.to).to eq([user.email])
      expect(subject.subject).to be_present
      expect(subject.from).to eq([SiteSetting.notification_email])
      expect(subject.body).to be_present
    end

  end

  describe ".forgot_password" do

    subject { UserNotifications.forgot_password(user) }

    it "works" do
      expect(subject.to).to eq([user.email])
      expect(subject.subject).to be_present
      expect(subject.from).to eq([SiteSetting.notification_email])
      expect(subject.body).to be_present
    end

  end

  describe '.mailing_list' do
    subject { UserNotifications.mailing_list(user) }

    context "without new posts" do
      it "doesn't send the email" do
        expect(subject.to).to be_blank
      end
    end

    context "with new posts" do
      let(:user) { Fabricate(:user) }
      let(:topic) { Fabricate(:topic, user: user) }
      let!(:new_post) { Fabricate(:post, topic: topic, created_at: 2.hours.ago, raw: "Feel the Bern") }
      let!(:old_post) { Fabricate(:post, topic: topic, created_at: 25.hours.ago, raw: "Make America Great Again") }
      let(:old_topic) { Fabricate(:topic, user: user, created_at: 10.days.ago) }
      let(:new_post_in_old_topic) { Fabricate(:post, topic: old_topic, created_at: 2.hours.ago, raw: "Yes We Can") }
      let(:stale_post) { Fabricate(:post, topic: old_topic, created_at: 2.days.ago, raw: "A New American Century") }

      it "works" do
        expect(subject.to).to eq([user.email])
        expect(subject.subject).to be_present
        expect(subject.from).to eq([SiteSetting.notification_email])
        expect(subject.html_part.body.to_s).to include topic.title
        expect(subject.text_part.body.to_s).to be_present
      end

      it "includes posts less than 24 hours old" do
        expect(subject.html_part.body.to_s).to include new_post.cooked
      end

      it "does not include posts older than 24 hours old" do
        expect(subject.html_part.body.to_s).to_not include old_post.cooked
      end

      it "includes topics created over 24 hours ago which have new posts" do
        new_post_in_old_topic
        expect(subject.html_part.body.to_s).to include old_topic.title
        expect(subject.html_part.body.to_s).to include new_post_in_old_topic.cooked
        expect(subject.html_part.body.to_s).to_not include stale_post.cooked
      end

      it "includes multiple topics" do
        new_post_in_old_topic
        expect(subject.html_part.body.to_s).to include topic.title
        expect(subject.html_part.body.to_s).to include old_topic.title
      end

      it "does not include topics not updated for the past 24 hours" do
        stale_post
        expect(subject.html_part.body.to_s).to_not include old_topic.title
        expect(subject.html_part.body.to_s).to_not include stale_post.cooked
      end

      it "includes email_prefix in email subject instead of site title" do
        SiteSetting.email_prefix = "Try Discourse"
        SiteSetting.title = "Discourse Meta"

        expect(subject.subject).to match(/Try Discourse/)
        expect(subject.subject).not_to match(/Discourse Meta/)
      end
    end
  end

  describe '.digest' do

    subject { UserNotifications.digest(user) }

    context "without new topics" do

      it "doesn't send the email" do
        expect(subject.to).to be_blank
      end

    end

    context "with new topics" do

      before do
        Topic.expects(:for_digest).returns([Fabricate(:topic, user: Fabricate(:coding_horror))])
        Topic.expects(:new_since_last_seen).returns(Topic.none)
      end

      it "works" do
        expect(subject.to).to eq([user.email])
        expect(subject.subject).to be_present
        expect(subject.from).to eq([SiteSetting.notification_email])
        expect(subject.html_part.body.to_s).to be_present
        expect(subject.text_part.body.to_s).to be_present
      end

      it "includes email_prefix in email subject instead of site title" do
        SiteSetting.email_prefix = "Try Discourse"
        SiteSetting.title = "Discourse Meta"

        expect(subject.subject).to match(/Try Discourse/)
        expect(subject.subject).not_to match(/Discourse Meta/)
      end
    end
  end

  describe '.user_replied' do
    let(:response_by_user) { Fabricate(:user, name: "John Doe") }
    let(:category) { Fabricate(:category, name: 'India') }
    let(:topic) { Fabricate(:topic, category: category) }
    let(:post) { Fabricate(:post, topic: topic, raw: 'This is My super duper cool topic') }
    let(:response) { Fabricate(:post, reply_to_post_number: 1, topic: post.topic, user: response_by_user)}
    let(:user) { Fabricate(:user) }
    let(:notification) { Fabricate(:notification, user: user) }

    it 'generates a correct email' do

      # Fabricator is not fabricating this ...
      SiteSetting.enable_names = true
      SiteSetting.display_name_on_posts = true
      mail = UserNotifications.user_replied(response.user,
                                             post: response,
                                             notification_type: notification.notification_type,
                                             notification_data_hash: notification.data_hash
                                           )
      # from should include full user name
      expect(mail[:from].display_names).to eql(['John Doe'])

      # subject should include category name
      expect(mail.subject).to match(/India/)

      mail_html = mail.html_part.to_s

      expect(mail_html.scan(/My super duper cool topic/).count).to eq(1)
      expect(mail_html.scan(/In Reply To/).count).to eq(1)

      # 2 "visit topic" link
      expect(mail_html.scan(/Visit Topic/).count).to eq(2)

      # 2 respond to links cause we have 1 context post
      expect(mail_html.scan(/to respond/).count).to eq(2)

      # 1 unsubscribe
      expect(mail_html.scan(/To unsubscribe/).count).to eq(1)

      # side effect, topic user is updated with post number
      tu = TopicUser.get(post.topic_id, response.user)
      expect(tu.last_emailed_post_number).to eq(response.post_number)


      # no In Reply To if user opts out
      response.user.user_option.email_in_reply_to = false
      mail = UserNotifications.user_replied(response.user,
                                             post: response,
                                             notification_type: notification.notification_type,
                                             notification_data_hash: notification.data_hash
                                           )


      expect(mail.html_part.to_s.scan(/In Reply To/).count).to eq(0)
    end
  end

  describe '.user_posted' do
    let(:response_by_user) { Fabricate(:user, name: "John Doe", username: "john") }
    let(:post) { Fabricate(:post) }
    let(:response) { Fabricate(:post, topic: post.topic, user: response_by_user)}
    let(:user) { Fabricate(:user) }
    let(:notification) { Fabricate(:notification, user: user, data: {original_username: response_by_user.username}.to_json) }

    it 'generates a correct email' do
      SiteSetting.enable_names = false
      mail = UserNotifications.user_posted(response.user,
                                           post: response,
                                           notification_type: notification.notification_type,
                                           notification_data_hash: notification.data_hash
                                          )

      # from should not include full user name if "show user full names" is disabled
      expect(mail[:from].display_names).to_not eql(['John Doe'])

      # from should include username if "show user full names" is disabled
      expect(mail[:from].display_names).to eql(['john'])

      # subject should not include category name
      expect(mail.subject).not_to match(/Uncategorized/)

      # 1 respond to links as no context by default
      expect(mail.html_part.to_s.scan(/to respond/).count).to eq(1)

      # 1 unsubscribe link
      expect(mail.html_part.to_s.scan(/To unsubscribe/).count).to eq(1)

      # side effect, topic user is updated with post number
      tu = TopicUser.get(post.topic_id, response.user)
      expect(tu.last_emailed_post_number).to eq(response.post_number)
    end
  end

  describe '.user_private_message' do
    let(:response_by_user) { Fabricate(:user, name: "", username: "john") }
    let(:topic) { Fabricate(:private_message_topic) }
    let(:response) { Fabricate(:post, topic: topic, user: response_by_user)}
    let(:user) { Fabricate(:user) }
    let(:notification) { Fabricate(:notification, user: user, data: {original_username: response_by_user.username}.to_json) }

    it 'generates a correct email' do
      SiteSetting.enable_names = true
      mail = UserNotifications.user_private_message(
        response.user,
        post: response,
        notification_type: notification.notification_type,
        notification_data_hash: notification.data_hash
      )

      # from should include username if full user name is not provided
      expect(mail[:from].display_names).to eql(['john'])

      # subject should include "[PM]"
      expect(mail.subject).to match("[PM]")

      # 1 "visit message" link
      expect(mail.html_part.to_s.scan(/Visit Message/).count).to eq(1)

      # 1 respond to link
      expect(mail.html_part.to_s.scan(/to respond/).count).to eq(1)

      # 1 unsubscribe link
      expect(mail.html_part.to_s.scan(/To unsubscribe/).count).to eq(1)

      # side effect, topic user is updated with post number
      tu = TopicUser.get(topic.id, response.user)
      expect(tu.last_emailed_post_number).to eq(response.post_number)
    end
  end


  it 'adds a warning when mail limit is reached' do
    SiteSetting.max_emails_per_day_per_user = 2
    user = Fabricate(:user)
    user.email_logs.create(email_type: 'blah', to_address: user.email, user_id: user.id, skipped: false)

    post = Fabricate(:post)
    reply = Fabricate(:post, topic_id: post.topic_id)

    notification = Fabricate(:notification, topic_id: post.topic_id, post_number: reply.post_number,
                             user: post.user, data: {original_username: 'bob'}.to_json)

    mail = UserNotifications.user_replied(
      user,
      post: reply,
      notification_type: notification.notification_type,
      notification_data_hash: notification.data_hash
    )

    # WARNING: you reached the limit of 100 email notifications per day. Further emails will be suppressed.
    # Consider watching less topics or disabling mailing list mode.
    expect(mail.html_part.to_s).to match("WARNING: ")
    expect(mail.body.to_s).to match("WARNING: ")
  end

  def expects_build_with(condition)
    UserNotifications.any_instance.expects(:build_email).with(user.email, condition)
    mailer = UserNotifications.send(mail_type, user,
                                    notification_type: Notification.types[notification.notification_type],
                                    notification_data_hash: notification.data_hash,
                                    post: notification.post)
    mailer.message
  end

  shared_examples "supports reply by email" do
    context "reply_by_email" do
      it "should have allow_reply_by_email set when that feature is enabled" do
        expects_build_with(has_entry(:allow_reply_by_email, true))
      end
    end
  end

  shared_examples "no reply by email" do
    context "reply_by_email" do
      it "doesn't support reply by email" do
        expects_build_with(Not(has_entry(:allow_reply_by_email, true)))
      end
    end
  end

  # The parts of emails that are derived from templates are translated
  shared_examples "sets user locale" do
    context "set locale for translating templates" do
      it "sets the locale" do
        expects_build_with(has_key(:locale))
      end
    end
  end

  shared_examples "notification email building" do
    let(:post) { Fabricate(:post, user: user) }
    let(:mail_type) { "user_#{notification_type}"}
    let(:username) { "walterwhite"}
    let(:notification) do
      Fabricate(:notification,
                user: user,
                topic: post.topic,
                notification_type: Notification.types[notification_type],
                post_number: post.post_number,
                data: {original_username: username}.to_json )
    end

    describe '.user_mentioned' do
      it "has a username" do
        expects_build_with(has_entry(:username, username))
      end

      it "has a url" do
        expects_build_with(has_key(:url))
      end

      it "has a template" do
        expects_build_with(has_entry(:template, "user_notifications.#{mail_type}"))
      end

      it "has a message" do
        expects_build_with(has_key(:message))
      end

      it "has a context" do
        expects_build_with(has_key(:context))
      end

      it "has an unsubscribe link" do
        expects_build_with(has_key(:add_unsubscribe_link))
      end

      it "has an post_id" do
        expects_build_with(has_key(:post_id))
      end

      it "has an topic_id" do
        expects_build_with(has_key(:topic_id))
      end

      it "should have user name as from_alias" do
        SiteSetting.enable_names = true
        SiteSetting.display_name_on_posts = true
        expects_build_with(has_entry(:from_alias, "#{user.name}"))
      end

      it "should not have user name as from_alias if display_name_on_posts is disabled" do
        SiteSetting.enable_names = false
        SiteSetting.display_name_on_posts = false
        expects_build_with(has_entry(:from_alias, "walterwhite"))
      end

      it "should explain how to respond" do
        expects_build_with(Not(has_entry(:include_respond_instructions, false)))
      end

      it "should not explain how to respond if the user is suspended" do
        User.any_instance.stubs(:suspended?).returns(true)
        expects_build_with(has_entry(:include_respond_instructions, false))
      end
    end
  end

  describe "user mentioned email" do
    include_examples "notification email building" do
      let(:notification_type) { :mentioned }
      include_examples "supports reply by email"
      include_examples "sets user locale"
    end
  end

  describe "user replied" do
    include_examples "notification email building" do
      let(:notification_type) { :replied }
      include_examples "supports reply by email"
      include_examples "sets user locale"
    end
  end

  describe "user quoted" do
    include_examples "notification email building" do
      let(:notification_type) { :quoted }
      include_examples "supports reply by email"
      include_examples "sets user locale"
    end
  end

  describe "user posted" do
    include_examples "notification email building" do
      let(:notification_type) { :posted }
      include_examples "supports reply by email"
      include_examples "sets user locale"
    end
  end

  describe "user invited to a private message" do
    include_examples "notification email building" do
      let(:notification_type) { :invited_to_private_message }
      include_examples "no reply by email"
      include_examples "sets user locale"
    end
  end

  describe "user invited to a topic" do
    include_examples "notification email building" do
      let(:notification_type) { :invited_to_topic }
      include_examples "no reply by email"
      include_examples "sets user locale"
    end
  end

  # notification emails derived from templates are translated into the user's locale
  shared_examples "notification derived from template" do
    let(:user) { Fabricate(:user, locale: locale) }
    let(:mail_type) { mail_type }
    let(:notification) { Fabricate(:notification, user: user) }
  end

  describe "notifications from template" do

    context "user locale has been set" do

      %w(signup signup_after_approval confirm_old_email notify_old_email confirm_new_email
         forgot_password admin_login account_created).each do |mail_type|
        include_examples "notification derived from template" do
          SiteSetting.default_locale = "en"
          let(:locale) { "fr" }
          let(:mail_type) { mail_type }
          it "sets the locale" do
            expects_build_with(has_entry(:locale, "fr"))
          end
        end
      end
    end

    context "user locale has not been set" do
      %w(signup signup_after_approval notify_old_email confirm_old_email confirm_new_email
         forgot_password admin_login account_created).each do |mail_type|
        include_examples "notification derived from template" do
          SiteSetting.default_locale = "en"
          let(:locale) { nil }
          let(:mail_type) { mail_type }
          it "sets the locale" do
            expects_build_with(has_entry(:locale, nil))
          end
        end
      end
    end

    context "user locale is an empty string" do
      %w(signup signup_after_approval notify_old_email confirm_new_email confirm_old_email
         forgot_password admin_login account_created).each do |mail_type|
        include_examples "notification derived from template" do
          SiteSetting.default_locale = "en"
          let(:locale) { "" }
          let(:mail_type) { mail_type }
          it "sets the locale" do
            expects_build_with(has_entry(:locale, nil))
          end
        end
      end
    end

  end
end
