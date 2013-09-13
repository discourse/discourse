require "spec_helper"

describe UserNotifications do

  let(:user) { Fabricate(:admin) }

  describe ".signup" do
    subject { UserNotifications.signup(user) }

    its(:to) { should == [user.email] }
    its(:subject) { should be_present }
    its(:from) { should == [SiteSetting.notification_email] }
    its(:body) { should be_present }
  end

  describe ".forgot_password" do
    subject { UserNotifications.forgot_password(user) }

    its(:to) { should == [user.email] }
    its(:subject) { should be_present }
    its(:from) { should == [SiteSetting.notification_email] }
    its(:body) { should be_present }
  end

  describe '.digest' do
    subject { UserNotifications.digest(user) }

    context "without new topics" do
      its(:to) { should be_blank }
    end

    context "with new topics" do
      before do
        Topic.expects(:for_digest).returns([Fabricate(:topic, user: Fabricate(:coding_horror))])
      end

      its(:to) { should == [user.email] }
      its(:subject) { should be_present }
      its(:from) { should == [SiteSetting.notification_email] }
      its(:body) { should be_present }
    end
  end

  describe '.user_replied' do
    let!(:post) { Fabricate(:post) }
    let!(:response) { Fabricate(:post, topic: post.topic)}
    let!(:user) { Fabricate(:user) }
    let!(:notification) { Fabricate(:notification, user: user) }

    it 'generates a correct email' do
      mail = UserNotifications.user_replied(response.user, post: response, notification: notification)

      # 2 respond to links cause we have 1 context post
      mail.html_part.to_s.scan(/To respond/).count.should == 2

      # 1 unsubscribe
      mail.html_part.to_s.scan(/To unsubscribe/).count.should == 1

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
                data: {display_username: username}.to_json )
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
        expects_build_with(has_entry(:from_alias, "#{username}"))
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
