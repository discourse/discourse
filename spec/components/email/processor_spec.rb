require "rails_helper"
require "email/processor"

describe Email::Processor do

  describe "rate limits" do

    let(:mail) { "From: foo@bar.com\nTo: bar@foo.com\nSubject: FOO BAR\n\nFoo foo bar bar?" }
    let(:limit_exceeded) { RateLimiter::LimitExceeded.new(10) }

    before do
      Email::Receiver.any_instance.expects(:process!).raises(limit_exceeded)
    end

    it "enqueues a background job by default" do
      Jobs.expects(:enqueue).with(:process_email, mail: mail)
      Email::Processor.process!(mail)
    end

    it "doesn't enqueue a background job when retry is disabled" do
      Jobs.expects(:enqueue).with(:process_email, mail: mail).never
      expect { Email::Processor.process!(mail, false) }.to raise_error(limit_exceeded)
    end

  end

end
