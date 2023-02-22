# frozen_string_literal: true

RSpec.describe Jobs::PollMailbox do
  let(:poller) { Jobs::PollMailbox.new }

  describe ".execute" do
    it "does no polling if pop3_polling_enabled is false" do
      SiteSetting.expects(:pop3_polling_enabled).returns(false)
      poller.expects(:poll_pop3).never
      poller.execute({})
    end

    it "polls when pop3_polling_enabled is true" do
      SiteSetting.expects(:pop3_polling_enabled).returns(true)
      poller.expects(:poll_pop3).once
      poller.execute({})
    end
  end

  describe ".poll_pop3" do
    # the date is dynamic here because there is a 1 week cutoff for
    # the pop3 polling
    let(:example_email) { email = <<~EMAIL }
        Return-Path: <one@foo.com>
        From: One <one@foo.com>
        To: team@bar.com
        Subject: Testing email
        Date: #{1.day.ago.strftime("%a, %d %b %Y")} 03:12:43 +0100
        Message-ID: <34@foo.bar.mail>
        Mime-Version: 1.0
        Content-Type: text/plain
        Content-Transfer-Encoding: 7bit

        This is an email example.
      EMAIL

    context "with pop errors" do
      before { Discourse.expects(:handle_job_exception).at_least_once }

      after { Discourse.redis.del(Jobs::PollMailbox::POLL_MAILBOX_TIMEOUT_ERROR_KEY) }

      it "add an admin dashboard message on pop authentication error" do
        Net::POP3.any_instance.expects(:start).raises(Net::POPAuthenticationError.new).at_least_once

        poller.poll_pop3

        i18n_key = "dashboard.poll_pop3_auth_error"

        expect(AdminDashboardData.problem_message_check(i18n_key)).to eq(
          I18n.t(i18n_key, base_path: Discourse.base_path),
        )
      end

      it "logs an error on pop connection timeout error" do
        Net::POP3.any_instance.expects(:start).raises(Net::OpenTimeout.new).at_least_once

        4.times { poller.poll_pop3 }

        i18n_key = "dashboard.poll_pop3_timeout"

        expect(AdminDashboardData.problem_message_check(i18n_key)).to eq(
          I18n.t(i18n_key, base_path: Discourse.base_path),
        )
      end

      it "logs an error when pop fails and continues with next message" do
        mail1 = Net::POPMail.new(1, nil, nil, nil)
        mail2 = Net::POPMail.new(2, nil, nil, nil)
        mail3 = Net::POPMail.new(3, nil, nil, nil)
        mail4 = Net::POPMail.new(4, nil, nil, nil)

        Net::POP3.any_instance.stubs(:start).yields(Net::POP3.new(nil, nil))
        Net::POP3.any_instance.stubs(:mails).returns([mail1, mail2, mail3, mail4])

        mail1.expects(:pop).raises(Net::POPError).once
        mail1.expects(:delete).never

        mail2.expects(:pop).returns(example_email).once
        mail2.expects(:delete).raises(Net::POPError).once

        mail3.expects(:pop).returns(example_email).once
        mail3.expects(:delete).never

        mail4.expects(:pop).returns(example_email).once
        mail4.expects(:delete).returns(example_email).once

        SiteSetting.pop3_polling_delete_from_server = true

        poller
          .expects(:mail_too_old?)
          .returns(false)
          .then
          .raises(RuntimeError)
          .then
          .returns(false)
          .times(3)
        poller.expects(:process_popmail).times(2)
        poller.poll_pop3
      end
    end

    context "with expired oauth2 access token" do
      before do
        Discourse.redis.set(Jobs::PollMailbox::POLL_MAILBOX_OAUTH2_AUTH_TOKEN_KEY, "old_access")

        Discourse.redis.expireat(
          Jobs::PollMailbox::POLL_MAILBOX_OAUTH2_AUTH_TOKEN_KEY,
          Time.now.to_i,
        )
      end
      after { Discourse.redis.del(Jobs::PollMailbox::POLL_MAILBOX_OAUTH2_AUTH_TOKEN_KEY) }

      it "refreshes the oauth2 auth token when expired" do
        SiteSetting.pop3_polling_oauth2 = true
        SiteSetting.pop3_polling_oauth2_refresh_token = "old_refresh"

        Net::POP3.any_instance.stubs(:start)
        Oauth2Pop3Token.expects(:get_new_tokens).returns(["access", "refresh", 20])

        poller.poll_pop3
        expect(Discourse.redis.get(Jobs::PollMailbox::POLL_MAILBOX_OAUTH2_AUTH_TOKEN_KEY)).to eq(
          "access",
        )
        expect(SiteSetting.pop3_polling_oauth2_refresh_token).to eq("refresh")
      end

      it "add an admin dashboard message on oauth2 refresh error" do
        SiteSetting.pop3_polling_oauth2 = true

        res = mock("http response")
        res.stubs(:code).returns(501)

        Net::POP3.any_instance.stubs(:start)
        Net::HTTP.stubs(:post_form).returns(res)
        Oauth2Pop3Token.expects(:refresh_access_token).raises(Oauth2RefreshFail).once
        Discourse.expects(:handle_job_exception).at_least_once

        poller.poll_pop3

        i18n_key = "dashboard.poll_pop3_oauth2_refresh_error"
        expect(AdminDashboardData.problem_message_check(i18n_key)).to eq(
          I18n.t(i18n_key, base_path: Discourse.base_path),
        )
      end
    end

    it "calls enable_ssl when the setting is enabled" do
      SiteSetting.pop3_polling_ssl = true
      Net::POP3.any_instance.stubs(:start)
      Net::POP3.any_instance.expects(:enable_ssl)
      poller.poll_pop3
    end

    it "does not call enable_ssl when the setting is disabled" do
      SiteSetting.pop3_polling_ssl = false
      Net::POP3.any_instance.stubs(:start)
      Net::POP3.any_instance.expects(:enable_ssl).never
      poller.poll_pop3
    end

    it "uses oauth2 when the setting is enabled" do
      SiteSetting.pop3_polling_oauth2 = true
      SiteSetting.pop3_polling_ssl = false
      Socket.stubs(:tcp)
      Oauth2Pop3Token.stubs(:refresh_access_token_if_needed)
      Net::POP3Command.any_instance.stubs(:recv_response).returns("+OK")
      Net::POP3.any_instance.stubs(:do_finish)
      Net::POP3.any_instance.stubs(:each_mail)
      Net::POP3Command.any_instance.stubs(:oauth2)
      Net::POP3Command.any_instance.expects(:oauth2)
      poller.poll_pop3
    end

    it "does not uses oauth2 when the setting is disabled" do
      SiteSetting.pop3_polling_oauth2 = false
      SiteSetting.pop3_polling_ssl = false
      Socket.stubs(:tcp)
      Oauth2Pop3Token.stubs(:refresh_access_token_if_needed)
      Net::POP3Command.any_instance.stubs(:recv_response).returns("+OK")
      Net::POP3.any_instance.stubs(:do_finish)
      Net::POP3.any_instance.stubs(:each_mail)
      Net::POP3Command.any_instance.stubs(:auth)
      Net::POP3Command.any_instance.expects(:oauth2).never
      poller.poll_pop3
    end

    it "does not refresh the oauth2 auth token when it is not expired" do
      Discourse.redis.setex(
        Jobs::PollMailbox::POLL_MAILBOX_OAUTH2_AUTH_TOKEN_KEY,
        20.seconds,
        "old_access",
      )
      SiteSetting.pop3_polling_oauth2 = true
      SiteSetting.pop3_polling_oauth2_refresh_token = "old_refresh"

      Net::POP3.any_instance.stubs(:start)
      Oauth2Pop3Token.expects(:refresh_access_token).never

      poller.poll_pop3

      Discourse.redis.del(Jobs::PollMailbox::POLL_MAILBOX_OAUTH2_AUTH_TOKEN_KEY)
    end

    context "when has emails" do
      let(:oldmail) { file_from_fixtures("old_destination.eml", "emails").read }

      before do
        mail1 = Net::POPMail.new(1, nil, nil, nil)
        mail2 = Net::POPMail.new(2, nil, nil, nil)
        mail3 = Net::POPMail.new(3, nil, nil, nil)
        mail4 = Net::POPMail.new(4, nil, nil, nil)
        Net::POP3.any_instance.stubs(:start).yields(Net::POP3.new(nil, nil))
        Net::POP3.any_instance.stubs(:mails).returns([mail1, mail2, mail3, mail4])
        Net::POP3.any_instance.expects(:delete_all).never
        mail1.stubs(:pop).returns(example_email)
        mail2.stubs(:pop).returns(example_email)
        mail3.stubs(:pop).returns(example_email)
        mail4.stubs(:pop).returns(oldmail)
        poller.expects(:process_popmail).times(3)
      end

      it "deletes emails from server when when deleting emails from server is enabled" do
        Net::POPMail.any_instance.stubs(:delete).times(3)
        SiteSetting.pop3_polling_delete_from_server = true
        poller.poll_pop3
      end

      it "does not delete emails server inbox when deleting emails from server is disabled" do
        Net::POPMail.any_instance.stubs(:delete).never
        SiteSetting.pop3_polling_delete_from_server = false
        poller.poll_pop3
      end

      it "does not process emails > 1 week old" do
        SiteSetting.pop3_polling_delete_from_server = false
        poller.poll_pop3
      end

      it "does not stop after an old email" do
        SiteSetting.pop3_polling_delete_from_server = false
        poller.expects(:mail_too_old?).returns(false, true, false, false).times(4)
        poller.poll_pop3
      end
    end
  end

  describe "#process_popmail" do
    def process_popmail(email_name)
      pop_mail = stub("pop mail")
      pop_mail.expects(:pop).returns(email(email_name))
      Jobs::PollMailbox.new.process_popmail(pop_mail.pop)
    end

    it "does not reply to a bounced email" do
      expect { process_popmail(:bounced_email) }.to_not change {
        ActionMailer::Base.deliveries.count
      }

      incoming_email = IncomingEmail.last

      expect(incoming_email.rejection_message).to eq(
        I18n.t("emails.incoming.errors.bounced_email_error"),
      )
    end
  end
end
