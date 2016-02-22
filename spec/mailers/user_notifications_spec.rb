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

      # default is only post #1
      expect(UserNotifications.get_context_posts(last, nil).count).to eq(1)
      # staff members can also see the whisper
      tu = TopicUser.new(topic: post1.topic, user: build(:moderator))
      expect(UserNotifications.get_context_posts(last, tu).count).to eq(2)
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
      expect(UserNotifications.get_context_posts(post3, topic_user).count).to eq(1)

      user.user_option.update_columns(email_previous_replies: UserOption.previous_replies_type[:never])
      expect(UserNotifications.get_context_posts(post3, topic_user).count).to eq(0)

      user.user_option.update_columns(email_previous_replies: UserOption.previous_replies_type[:always])
      expect(UserNotifications.get_context_posts(post3, topic_user).count).to eq(2)

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
    let(:post) { Fabricate(:post, topic: topic) }
    let(:response) { Fabricate(:post, topic: post.topic, user: response_by_user)}
    let(:user) { Fabricate(:user) }
    let(:notification) { Fabricate(:notification, user: user) }

    it 'generates a correct email' do
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

      # 2 "visit topic" link
      expect(mail.html_part.to_s.scan(/Visit Topic/).count).to eq(2)

      # 2 respond to links cause we have 1 context post
      expect(mail.html_part.to_s.scan(/to respond/).count).to eq(2)

      # 1 unsubscribe
      expect(mail.html_part.to_s.scan(/To unsubscribe/).count).to eq(1)

      # side effect, topic user is updated with post number
      tu = TopicUser.get(post.topic_id, response.user)
      expect(tu.last_emailed_post_number).to eq(response.post_number)
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

      # 2 respond to links cause we have 1 context post
      expect(mail.html_part.to_s.scan(/to respond/).count).to eq(2)

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
    end
  end

  describe "user replied" do
    include_examples "notification email building" do
      let(:notification_type) { :replied }
      include_examples "supports reply by email"
    end
  end

  describe "user quoted" do
    include_examples "notification email building" do
      let(:notification_type) { :quoted }
      include_examples "supports reply by email"
    end
  end

  describe "user posted" do
    include_examples "notification email building" do
      let(:notification_type) { :posted }
      include_examples "supports reply by email"
    end
  end

  describe "user invited to a private message" do
    include_examples "notification email building" do
      let(:notification_type) { :invited_to_private_message }
      include_examples "no reply by email"
    end
  end

  describe "user invited to a topic" do
    include_examples "notification email building" do
      let(:notification_type) { :invited_to_topic }
      include_examples "no reply by email"
    end
  end

end
