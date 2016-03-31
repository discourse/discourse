require 'rails_helper'
require_dependency 'jobs/regular/process_post'

describe Jobs::PollMailbox do

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

    it "logs an error on pop authentication error" do
      Net::POP3.any_instance.expects(:start).raises(Net::POPAuthenticationError.new)
      Discourse.expects(:handle_job_exception)
      poller.poll_pop3
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
  end

end
