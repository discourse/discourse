require 'rails_helper'
require_dependency 'jobs/base'

describe Jobs::UserEmail do

  before do
    SiteSetting.email_time_window_mins = 10
  end

  let(:user) { Fabricate(:user, last_seen_at: 11.minutes.ago) }
  let(:staged) { Fabricate(:user, staged: true, last_seen_at: 11.minutes.ago) }
  let(:suspended) { Fabricate(:user, last_seen_at: 10.minutes.ago, suspended_at: 5.minutes.ago, suspended_till: 7.days.from_now) }
  let(:anonymous) { Fabricate(:anonymous, last_seen_at: 11.minutes.ago) }
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

  it "doesn't call the mailer when the user is staged" do
    UserNotifications.expects(:digest).never
    Jobs::UserEmail.new.execute(type: :digest, user_id: staged.id)
  end

  context "bounce score" do

    it "always sends critical emails when bounce score threshold has been reached" do
      email_token = Fabricate(:email_token)
      user.user_stat.update(bounce_score: SiteSetting.bounce_score_threshold + 1)

      Jobs::CriticalUserEmail.new.execute(type: "signup", user_id: user.id, email_token: email_token.token)

      email_log = EmailLog.where(user_id: user.id).last
      expect(email_log.email_type).to eq("signup")
      expect(email_log.skipped).to eq(false)
    end

  end

  context 'to_address' do
    it 'overwrites a to_address when present' do
      UserNotifications.expects(:confirm_new_email).returns(mailer)
      Email::Sender.any_instance.expects(:send)
      Jobs::UserEmail.new.execute(type: :confirm_new_email, user_id: user.id, to_address: 'jake@adventuretime.ooo')
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
      user.update_attributes(last_seen_at: 9.minutes.ago)
      user.user_option.update_attributes(email_always: true)
      PostTiming.create!(topic_id: post.topic_id, post_number: post.post_number, user_id: user.id, msecs: 100)

      Email::Sender.any_instance.expects(:send)
      Jobs::UserEmail.new.execute(type: :user_replied, user_id: user.id, post_id: post.id)
    end
  end

  context "email_log" do

    before do
      SiteSetting.editing_grace_period = 0
      Fabricate(:post)
    end

    it "creates an email log when the mail is sent (via Email::Sender)" do
      last_emailed_at = user.last_emailed_at

      expect { Jobs::UserEmail.new.execute(type: :digest, user_id: user.id) }.to change { EmailLog.count }.by(1)

      email_log = EmailLog.last
      expect(email_log.skipped).to eq(false)
      expect(email_log.user_id).to eq(user.id)

      # last_emailed_at should have changed
      expect(email_log.user.last_emailed_at).to_not eq(last_emailed_at)
    end

    it "creates an email log when the mail is skipped" do
      last_emailed_at = user.last_emailed_at
      user.update_columns(suspended_till: 1.year.from_now)

      expect { Jobs::UserEmail.new.execute(type: :digest, user_id: user.id) }.to change { EmailLog.count }.by(1)

      email_log = EmailLog.last
      expect(email_log.skipped).to eq(true)
      expect(email_log.skipped_reason).to be_present
      expect(email_log.user_id).to eq(user.id)

      # last_emailed_at doesn't change
      expect(email_log.user.last_emailed_at).to eq(last_emailed_at)
    end

  end

  context 'args' do

    it 'passes a token as an argument when a token is present' do
      UserNotifications.expects(:forgot_password).with(user, email_token: 'asdfasdf').returns(mailer)
      Email::Sender.any_instance.expects(:send)
      Jobs::UserEmail.new.execute(type: :forgot_password, user_id: user.id, email_token: 'asdfasdf')
    end

    context "post" do
      let(:post) { Fabricate(:post, user: user) }

      it 'passes a post as an argument when a post_id is present' do
        UserNotifications.expects(:user_private_message).with(user, post: post).returns(mailer)
        Email::Sender.any_instance.expects(:send)
        Jobs::UserEmail.new.execute(type: :user_private_message, user_id: user.id, post_id: post.id)
      end

      it "doesn't send the email if you've seen the post" do
        Email::Sender.any_instance.expects(:send).never
        PostTiming.record_timing(topic_id: post.topic_id, user_id: user.id, post_number: post.post_number, msecs: 6666)
        Jobs::UserEmail.new.execute(type: :user_private_message, user_id: user.id, post_id: post.id)
      end

      it "doesn't send the email if the user deleted the post" do
        Email::Sender.any_instance.expects(:send).never
        post.update_column(:user_deleted, true)
        Jobs::UserEmail.new.execute(type: :user_private_message, user_id: user.id, post_id: post.id)
      end

      it "doesn't send the email if user of the post has been deleted" do
        Email::Sender.any_instance.expects(:send).never
        post.update_attributes!(user_id: nil)
        Jobs::UserEmail.new.execute(type: :user_replied, user_id: user.id, post_id: post.id)
      end

      context 'user is suspended' do
        it "doesn't send email for a pm from a regular user" do
          Email::Sender.any_instance.expects(:send).never
          Jobs::UserEmail.new.execute(type: :user_private_message, user_id: suspended.id, post_id: post.id)
        end

        it "does send an email for a pm from a staff user" do
          pm_from_staff = Fabricate(:post, user: Fabricate(:moderator))
          pm_from_staff.topic.topic_allowed_users.create!(user_id: suspended.id)
          Email::Sender.any_instance.expects(:send)
          Jobs::UserEmail.new.execute(type: :user_private_message, user_id: suspended.id, post_id: pm_from_staff.id)
        end
      end

      context 'user is anonymous' do
        before { SiteSetting.allow_anonymous_posting = true }

        it "doesn't send email for a pm from a regular user" do
          Email::Sender.any_instance.expects(:send).never
          Jobs::UserEmail.new.execute(type: :user_private_message, user_id: anonymous.id, post_id: post.id)
        end

        it "doesn't send email for a pm from a staff user" do
          pm_from_staff = Fabricate(:post, user: Fabricate(:moderator))
          pm_from_staff.topic.topic_allowed_users.create!(user_id: anonymous.id)
          Email::Sender.any_instance.expects(:send).never
          Jobs::UserEmail.new.execute(type: :user_private_message, user_id: anonymous.id, post_id: pm_from_staff.id)
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

      it "doesn't send the email if the notification has been seen" do
        notification.update_column(:read, true)
        message, err = Jobs::UserEmail.new.message_for_email(
          user,
          post,
          :user_mentioned,
          notification,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash
        )

        expect(message).to eq nil
        expect(err.skipped_reason).to match(/notification.*already/)
      end

      it "does send the email if the notification has been seen but the user is set for email_always" do
        Email::Sender.any_instance.expects(:send)
        notification.update_column(:read, true)
        user.user_option.update_column(:email_always, true)
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_id: notification.id)
      end

      it "does send the email if the user is using daily mailing list mode" do
        Email::Sender.any_instance.expects(:send)
        user.user_option.update(mailing_list_mode: true, mailing_list_mode_frequency: 0)

        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_id: notification.id)
      end

      context 'max_emails_per_day_per_user limit is reached' do
        before do
          SiteSetting.max_emails_per_day_per_user = 2
          2.times { Fabricate(:email_log, user: user, email_type: 'blah', to_address: user.email) }
        end

        it "does not send notification if limit is reached" do
          Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_id: notification.id, post_id: post.id)
          expect(EmailLog.where(user_id: user.id, skipped: true).count).to eq(1)
        end

        it "sends critical email" do
          Jobs::UserEmail.new.execute(type: :forgot_password, user_id: user.id, notification_id: notification.id, post_id: post.id)
          expect(EmailLog.where(user_id: user.id, skipped: true).count).to eq(0)
        end
      end

      it "does not send notification if bounce threshold is reached" do
        user.user_stat.update(bounce_score: SiteSetting.bounce_score_threshold)
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_id: notification.id, post_id: post.id)
        expect(EmailLog.where(user_id: user.id, skipped: true).count).to eq(1)
      end

      it "doesn't send the mail if the user is using individual mailing list mode" do
        Email::Sender.any_instance.expects(:send).never
        user.user_option.update(mailing_list_mode: true, mailing_list_mode_frequency: 1)
        # sometimes, we pass the notification_id
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_id: notification.id, post_id: post.id)
        # other times, we only pass the type of notification
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_type: "posted", post_id: post.id)
        # When post is nil
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_type: "posted")
        # When post does not have a topic
        post = Fabricate(:post)
        post.topic.destroy
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_type: "posted", post_id: post.id)
      end

      it "doesn't send the mail if the user is using individual mailing list mode with no echo" do
        Email::Sender.any_instance.expects(:send).never
        user.user_option.update(mailing_list_mode: true, mailing_list_mode_frequency: 2)
        # sometimes, we pass the notification_id
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_id: notification.id, post_id: post.id)
        # other times, we only pass the type of notification
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_type: "posted", post_id: post.id)
        # When post is nil
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_type: "posted")
        # When post does not have a topic
        post = Fabricate(:post)
        post.topic.destroy
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_type: "posted", post_id: post.id)
      end

      it "doesn't send the email if the post has been user deleted" do
        Email::Sender.any_instance.expects(:send).never
        post.update_column(:user_deleted, true)
        Jobs::UserEmail.new.execute(type: :user_mentioned, user_id: user.id, notification_id: notification.id, post_id: post.id)
      end

      context 'user is suspended' do
        it "doesn't send email for a pm from a regular user" do
          msg, err = Jobs::UserEmail.new.message_for_email(
              suspended,
              Fabricate.build(:post),
              :user_private_message,
              notification
          )

          expect(msg).to eq(nil)
          expect(err).not_to eq(nil)
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
          end

          let :sent_message do
            Jobs::UserEmail.new.message_for_email(
                suspended,
                @pm_from_staff,
                :user_private_message,
                @pm_notification
            )
          end

          it "sends an email" do
            msg, err = sent_message
            expect(msg).not_to be(nil)
            expect(err).to be(nil)
          end

          it "sends an email even if user was last seen recently" do
            suspended.update_column(:last_seen_at, 1.minute.ago)

            msg, err = sent_message
            expect(msg).not_to be(nil)
            expect(err).to be(nil)
          end
        end
      end

      context 'user is anonymous' do
        before { SiteSetting.allow_anonymous_posting = true }

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
