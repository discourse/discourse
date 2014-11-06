require "spec_helper"

describe UserNotifications do

  let(:user) { Fabricate(:admin) }

  describe "#get_context_posts" do
    it "does not include hidden/deleted/user_deleted posts in context" do
      post = create_post
      reply1 = create_post(topic: post.topic)
      reply2 = create_post(topic: post.topic)
      reply3 = create_post(topic: post.topic)
      reply4 = create_post(topic: post.topic)

      reply1.trash!

      reply2.user_deleted = true
      reply2.save

      reply3.hidden = true
      reply3.save

      UserNotifications.get_context_posts(reply4, nil).count.should == 1
    end
  end

  describe ".signup" do

    subject { UserNotifications.signup(user) }

    it "works" do
      subject.to.should == [user.email]
      subject.subject.should be_present
      subject.from.should == [SiteSetting.notification_email]
      subject.body.should be_present
    end

  end

  describe ".forgot_password" do

    subject { UserNotifications.forgot_password(user) }

    it "works" do
      subject.to.should == [user.email]
      subject.subject.should be_present
      subject.from.should == [SiteSetting.notification_email]
      subject.body.should be_present
    end

  end

  describe '.digest' do

    subject { UserNotifications.digest(user) }

    context "without new topics" do

      it "doesn't send the email" do
        subject.to.should be_blank
      end

    end

    context "with new topics" do

      before do
        Topic.expects(:for_digest).returns([Fabricate(:topic, user: Fabricate(:coding_horror))])
        Topic.expects(:new_since_last_seen).returns(Topic.none)
      end

      it "works" do
        subject.to.should == [user.email]
        subject.subject.should be_present
        subject.from.should == [SiteSetting.notification_email]
        subject.html_part.body.to_s.should be_present
        subject.text_part.body.to_s.should be_present
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
      SiteSetting.stubs(:enable_email_names).returns(true)
      mail = UserNotifications.user_replied(response.user, post: response, notification: notification)

      # from should include full user name
      expect(mail[:from].display_names).to eql(['John Doe'])

      # subject should include category name
      expect(mail.subject).to match(/India/)

      # 2 respond to links cause we have 1 context post
      mail.html_part.to_s.scan(/To respond/).count.should == 2

      # 1 unsubscribe
      mail.html_part.to_s.scan(/To unsubscribe/).count.should == 1

      # side effect, topic user is updated with post number
      tu = TopicUser.get(post.topic_id, response.user)
      tu.last_emailed_post_number.should == response.post_number

      # in mailing list mode user_replies is not sent through
      response.user.mailing_list_mode = true
      mail = UserNotifications.user_replied(response.user, post: response, notification: notification)
      mail.class.should == ActionMailer::Base::NullMail


      response.user.mailing_list_mode = nil
      mail = UserNotifications.user_replied(response.user, post: response, notification: notification)

      mail.class.should_not == ActionMailer::Base::NullMail

    end
  end

  describe '.user_posted' do
    let(:response_by_user) { Fabricate(:user, name: "John Doe") }
    let(:post) { Fabricate(:post) }
    let(:response) { Fabricate(:post, topic: post.topic, user: response_by_user)}
    let(:user) { Fabricate(:user) }
    let(:notification) { Fabricate(:notification, user: user) }

    it 'generates a correct email' do
      SiteSetting.stubs(:enable_email_names).returns(false)
      mail = UserNotifications.user_posted(response.user, post: response, notification: notification)

      # from should not include full user name if "show user full names" is disabled
      expect(mail[:from].display_names).to_not eql(['John Doe'])

      # subject should not include category name
      expect(mail.subject).not_to match(/Uncategorized/)

      # 2 respond to links cause we have 1 context post
      mail.html_part.to_s.scan(/To respond/).count.should == 2

      # 1 unsubscribe link
      mail.html_part.to_s.scan(/To unsubscribe/).count.should == 1

      # side effect, topic user is updated with post number
      tu = TopicUser.get(post.topic_id, response.user)
      tu.last_emailed_post_number.should == response.post_number
    end
  end

  describe '.user_private_message' do
    let(:response_by_user) { Fabricate(:user, name: "John Doe") }
    let(:topic) { Fabricate(:private_message_topic) }
    let(:response) { Fabricate(:post, topic: topic, user: response_by_user)}
    let(:user) { Fabricate(:user) }
    let(:notification) { Fabricate(:notification, user: user) }

    it 'generates a correct email' do
      SiteSetting.stubs(:enable_email_names).returns(true)
      mail = UserNotifications.user_private_message(response.user, post: response, notification: notification)

      # from should include full user name
      expect(mail[:from].display_names).to eql(['John Doe'])

      # subject should include "[PM]"
      expect(mail.subject).to match("[PM]")

      # 1 respond to link
      mail.html_part.to_s.scan(/To respond/).count.should == 1

      # 1 unsubscribe link
      mail.html_part.to_s.scan(/To unsubscribe/).count.should == 1

      # side effect, topic user is updated with post number
      tu = TopicUser.get(topic.id, response.user)
      tu.last_emailed_post_number.should == response.post_number
    end
  end

  def expects_build_with(condition)
    UserNotifications.any_instance.expects(:build_email).with(user.email, condition)
    UserNotifications.send(mail_type, user, notification: notification, post: notification.post)
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

      it "has a from alias" do
        SiteSetting.stubs(:enable_email_names).returns(true)
        expects_build_with(has_entry(:from_alias, "#{user.name}"))
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

end
