require "rails_helper"

describe Jobs::NotifyMailingListSubscribers do

  context "with mailing list on" do
    before do
      SiteSetting.default_email_mailing_list_mode = true
      SiteSetting.default_email_mailing_list_mode_frequency = 1
    end
    let(:user) { Fabricate(:user) }

    context "SiteSetting.max_emails_per_day_per_user" do

      it 'stops sending mail once limit is reached' do
        SiteSetting.max_emails_per_day_per_user = 2
        post = Fabricate(:post)

        user.email_logs.create(email_type: 'blah', to_address: user.email, user_id: user.id)
        user.email_logs.create(email_type: 'blah', to_address: user.email, user_id: user.id)

        Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
        expect(EmailLog.where(user_id: user.id, skipped: true).count).to eq(1)
      end
    end

    context "totally skipped if mailing list mode disabled" do

      it "sends no email to the user" do
        SiteSetting.disable_mailing_list_mode = true

        post = Fabricate(:post)
        Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
        expect(EmailLog.count).to eq(0)
      end
    end

    context "with a valid post" do
      let!(:post) { Fabricate(:post, user: user) }

      it "sends the email to the user if the frequency is set to 'always'" do
        user.user_option.update(mailing_list_mode: true, mailing_list_mode_frequency: 1)
        UserNotifications.expects(:mailing_list_notify).with(user, post).once
        Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
      end

      it "does not send the email to the user if the frequency is set to 'daily'" do
        user.user_option.update(mailing_list_mode: true, mailing_list_mode_frequency: 0)
        UserNotifications.expects(:mailing_list_notify).never
        Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
      end
    end

    context "with a deleted post" do
      let!(:post) { Fabricate(:post, user: user, deleted_at: Time.now) }

      it "doesn't send the email to the user" do
        UserNotifications.expects(:mailing_list_notify).with(user, post).never
        Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
      end
    end

    context "with a user_deleted post" do
      let!(:post) { Fabricate(:post, user: user, user_deleted: true) }

      it "doesn't send the email to the user" do
        UserNotifications.expects(:mailing_list_notify).with(user, post).never
        Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
      end
    end

    context "with a deleted topic" do
      let!(:post) { Fabricate(:post, user: user) }

      before do
        post.topic.update_column(:deleted_at, Time.now)
      end

      it "doesn't send the email to the user" do
        UserNotifications.expects(:mailing_list_notify).with(user, post).never
        Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
      end
    end

    context "to an anonymous user" do
      let(:user) { Fabricate(:anonymous) }
      let!(:post) { Fabricate(:post, user: user) }

      it "doesn't send the email to the user" do
        UserNotifications.expects(:mailing_list_notify).with(user, post).never
        Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
      end
    end

  end

  context "with mailing list off" do
    before { SiteSetting.stubs(:default_email_mailing_list_mode).returns(false) }

    let(:user) { Fabricate(:user) }
    let!(:post) { Fabricate(:post, user: user) }

    it "doesn't send the email to the user" do
      UserNotifications.expects(:mailing_list_notify).never
      Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
    end
  end

end
