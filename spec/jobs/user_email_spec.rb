require 'spec_helper'
require_dependency 'jobs/base'

describe Jobs::UserEmail do

  before do
    SiteSetting.stubs(:email_time_window_mins).returns(10)
  end

  let(:user) { Fabricate(:user, last_seen_at: 11.minutes.ago ) }
  let(:suspended) { Fabricate(:user, last_seen_at: 10.minutes.ago, suspended_at: 5.minutes.ago, suspended_till: 7.days.from_now ) }
  let(:anonymous) { Fabricate(:anonymous, last_seen_at: 11.minutes.ago ) }
  let(:mailer) { Mail::Message.new(to: user.email) }

  it "raises an error when there is no user" do
    expect { Jobs::UserEmail.new.execute(type: :digest) }.to raise_error(Discourse::InvalidParameters)
  end

  it "raises an error when there is no type" do
    expect { Jobs::UserEmail.new.execute(user_id: user.id) }.to raise_error(Discourse::InvalidParameters)
  end

  it "raises an error when the type doesn't exist" do
    expect { Jobs::UserEmail.new.execute(type: :no_method, user_id: user.id) }.to raise_error(Discourse::InvalidParameters)
  end

  it "doesn't call the mailer when the user is missing" do
    UserNotifications.expects(:digest).never
    Jobs::UserEmail.new.execute(type: :digest, user_id: 1234)
  end


  context 'to_address' do
    it 'overwrites a to_address when present' do
      UserNotifications.expects(:authorize_email).returns(mailer)
      Email::Sender.any_instance.expects(:send)
      Jobs::UserEmail.new.execute(type: :authorize_email, user_id: user.id, to_address: 'jake@adventuretime.ooo')
      expect(mailer.to).to eq(['jake@adventuretime.ooo'])
    end
  end

  context "recently seen" do
    let(:post) { Fabricate(:post, user: user) }

    it "doesn't send an email to a user that's been recently seen" do
      user.update_column(:last_seen_at, 9.minutes.ago)
      Email::Sender.any_instance.expects(:send).never
      Jobs::UserEmail.new.execute(type: :user_replied, user_id: user.id, post_id: post.id)
    end

    it "does send an email to a user that's been recently seen but has email_always set" do
      user.update_attributes(last_seen_at: 9.minutes.ago, email_always: true)
      Email::Sender.any_instance.expects(:send)
      Jobs::UserEmail.new.execute(type: :user_replied, user_id: user.id, post_id: post.id)
    end
  end

  context 'args' do

    it 'passes a token as an argument when a token is present' do
      UserNotifications.expects(:forgot_password).with(user, {email_token: 'asdfasdf'}).returns(mailer)
      Email::Sender.any_instance.expects(:send)
      Jobs::UserEmail.new.execute(type: :forgot_password, user_id: user.id, email_token: 'asdfasdf')
    end

    context "post" do
      let(:post) { Fabricate(:post, user: user) }

      it 'passes a post as an argument when a post_id is present' do
        UserNotifications.expects(:private_message).with(user, {post: post}).returns(mailer)
        Email::Sender.any_instance.expects(:send)
        Jobs::UserEmail.new.execute(type: :private_message, user_id: user.id, post_id: post.id)
      end

      it "doesn't send the email if you've seen the post" do
        Email::Sender.any_instance.expects(:send).never
        PostTiming.record_timing(topic_id: post.topic_id, user_id: user.id, post_number: post.post_number, msecs: 6666)
        Jobs::UserEmail.new.execute(type: :private_message, user_id: user.id, post_id: post.id)
      end

      it "doesn't send the email if the user deleted the post" do
        Email::Sender.any_instance.expects(:send).never
        post.update_column(:user_deleted, true)
        Jobs::UserEmail.new.execute(type: :private_message, user_id: user.id, post_id: post.id)
      end

      context 'user is suspended' do
        it "doesn't send email for a pm from a regular user" do
          Email::Sender.any_instance.expects(:send).never
          Jobs::UserEmail.new.execute(type: :private_message, user_id: suspended.id, post_id: post.id)
        end

        it "doesn't send email for a pm from a staff user" do
          pm_from_staff = Fabricate(:post, user: Fabricate(:moderator))
          pm_from_staff.topic.topic_allowed_users.create!(user_id: suspended.id)
          Email::Sender.any_instance.expects(:send).never
          Jobs::UserEmail.new.execute(type: :private_message, user_id: suspended.id, post_id: pm_from_staff.id)
        end
      end

      context 'user is anonymous' do
        before { SiteSetting.stubs(:allow_anonymous_posting).returns(true) }

        it "doesn't send email for a pm from a regular user" do
          Email::Sender.any_instance.expects(:send).never
          Jobs::UserEmail.new.execute(type: :private_message, user_id: anonymous.id, post_id: post.id)
        end

        it "doesn't send email for a pm from a staff user" do
          pm_from_staff = Fabricate(:post, user: Fabricate(:moderator))
          pm_from_staff.topic.topic_allowed_users.create!(user_id: anonymous.id)
          Email::Sender.any_instance.expects(:send).never
          Jobs::UserEmail.new.execute(type: :private_message, user_id: anonymous.id, post_id: pm_from_staff.id)
        end
      end
    end


    context 'notification' do
      let(:post) { Fabricate(:post, user: user) }
      let!(:notification) {
        Fabricate(:notification,
                    user: user,
                    topic: post.topic,
                    post_number: post.post_number,
                    data: {
                      original_post_id: post.id
                    }.to_json
                 )
      }

      it 'passes a notification as an argument when a notification_id is present' do
        Email::Sender.any_instance.expects(:send)
        UserNotifications.expects(:user_mentioned).with(user, notification: notification, post: post).returns(mailer)
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_id: notification.id)
      end

      it "doesn't send the email if the notification has been seen" do
        Email::Sender.any_instance.expects(:send).never
        notification.update_column(:read, true)
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_id: notification.id)
      end

      it "does send the email if the notification has been seen but the user is set for email_always" do
        Email::Sender.any_instance.expects(:send)
        notification.update_column(:read, true)
        user.update_column(:email_always, true)
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_id: notification.id)
      end

      it "doesn't send the email if the post has been user deleted" do
        Email::Sender.any_instance.expects(:send).never
        post.update_column(:user_deleted, true)
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_id: notification.id)
      end

      context 'user is suspended' do
        it "doesn't send email for a pm from a regular user" do
          Email::Sender.any_instance.expects(:send).never
          Jobs::UserEmail.new.execute(type: :user_private_message, user_id: suspended.id, notification_id: notification.id)
        end

        context 'pm from staff' do
          before do
            @pm_from_staff = Fabricate(:post, user: Fabricate(:moderator))
            @pm_from_staff.topic.topic_allowed_users.create!(user_id: suspended.id)
            @pm_notification = Fabricate(:notification,
                                            user: suspended,
                                            topic: @pm_from_staff.topic,
                                            post_number: @pm_from_staff.post_number,
                                            data: { original_post_id: @pm_from_staff.id }.to_json
                                        )
            UserNotifications.expects(:user_private_message).with(suspended, notification: @pm_notification, post: @pm_from_staff).returns(mailer)
          end

          subject(:execute_user_email_job) {
            Jobs::UserEmail.new.execute(type: :user_private_message, user_id: suspended.id, notification_id: @pm_notification.id) }

          it "sends an email" do
            execute_user_email_job
          end

          it "sends an email even if user was last seen recently" do
            suspended.update_column(:last_seen_at, 1.minute.ago)
            execute_user_email_job
          end
        end
      end

      context 'user is anonymous' do
        before { SiteSetting.stubs(:allow_anonymous_posting).returns(true) }

        it "doesn't send email for a pm from a regular user" do
          Email::Sender.any_instance.expects(:send).never
          Jobs::UserEmail.new.execute(type: :user_private_message, user_id: anonymous.id, notification_id: notification.id)
        end

        it "doesn't send email for a pm from staff" do
          pm_from_staff = Fabricate(:post, user: Fabricate(:moderator))
          pm_from_staff.topic.topic_allowed_users.create!(user_id: anonymous.id)
          pm_notification = Fabricate(:notification,
                                          user: anonymous,
                                          topic: pm_from_staff.topic,
                                          post_number: pm_from_staff.post_number,
                                          data: { original_post_id: pm_from_staff.id }.to_json
                                      )
          Email::Sender.any_instance.expects(:send).never
          Jobs::UserEmail.new.execute(type: :user_private_message, user_id: anonymous.id, notification_id: pm_notification.id)
        end
      end
    end

  end


end

