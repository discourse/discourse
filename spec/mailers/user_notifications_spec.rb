require "spec_helper"

describe UserNotifications do

  let(:user) { Fabricate(:user) }

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

  describe '.daily_digest' do
    subject { UserNotifications.digest(user) }

    context "without new topics" do
      its(:to) { should be_blank }
    end

    context "with new topics" do
      before do
        Topic.expects(:new_topics).returns([Fabricate(:topic, user: Fabricate(:coding_horror))])
      end

      its(:to) { should == [user.email] }
      its(:subject) { should be_present }
      its(:from) { should == [SiteSetting.notification_email] }
      its(:body) { should be_present }
    end
  end

  describe '.user_mentioned' do

    let(:post) { Fabricate(:post, user: user) }
    let(:username) { "walterwhite"}

    let(:notification) do
      Fabricate(:notification, user: user, topic: post.topic, post_number: post.post_number, data: {display_username: username}.to_json )
    end

    subject { UserNotifications.user_mentioned(user, notification: notification, post: notification.post) }

    its(:to) { should == [user.email] }
    its(:subject) { should be_present }
    its(:from) { should == [SiteSetting.notification_email] }

    it "should have the correct from address" do
      subject.header['from'].to_s.should == "#{username} via #{SiteSetting.title} <#{SiteSetting.notification_email}>"
    end


    its(:body) { should be_present }
  end


end
