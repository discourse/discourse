require 'spec_helper'
require_dependency 'jobs/regular/process_post'

describe Jobs::PollMailbox do


  let(:poller) { Jobs::PollMailbox.new }

  it "does no polling if pop3s_polling_enabled is false" do
    SiteSetting.expects(:pop3s_polling_enabled?).returns(false)
    poller.expects(:poll_pop3s).never
    poller.execute({})
  end

  describe "with pop3s_polling_enabled" do

    it "calls poll_pop3s" do
      SiteSetting.expects(:pop3s_polling_enabled?).returns(true)
      poller.expects(:poll_pop3s).once
      poller.execute({})
    end
  end

end
