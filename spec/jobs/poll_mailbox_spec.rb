# frozen_string_literal: true
require "email/poller"

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

        i18n_key = "dashboard.problem.poll_pop3_auth_error"

        expect(AdminNotice.find_by(identifier: "poll_pop3_auth_error").message).to eq(
          I18n.t(i18n_key, base_path: Discourse.base_path),
        )
      end

      it "logs an error on pop connection timeout error" do
        Net::POP3.any_instance.expects(:start).raises(Net::OpenTimeout.new).at_least_once

        4.times { poller.poll_pop3 }

        i18n_key = "dashboard.problem.poll_pop3_timeout"

        expect(AdminNotice.find_by(identifier: "poll_pop3_timeout").message).to eq(
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

  describe "poller plugin" do
    let(:poller_plugin) do
      Class
        .new(described_class) do
          def set_enabled(e)
            @enabled = e
          end

          def enabled?
            @enabled
          end

          def poll_mailbox(process_cb)
            process_cb.call(file_from_fixtures("original_message.eml", "emails"))
          end
        end
        .new
    end

    let(:plugin) { Plugin::Instance.new }

    before(:each) { plugin.register_email_poller(poller_plugin) }

    after(:each) do
      Discourse.plugins.delete plugin
      DiscoursePluginRegistry.reset!
    end

    it "doesn't call process method when plugin is not active" do
      poller_plugin.set_enabled(false)
      poller.expects(:process_popmail).never
      poller.execute({})
    end

    it "calls process method when plugin is active" do
      poller_plugin.set_enabled(true)
      poller.expects(:process_popmail).once
      poller.execute({})
    end
  end
end
