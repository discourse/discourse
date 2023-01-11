# frozen_string_literal: true

RSpec.describe Jobs::ProcessEmail do
  let(:mail) { "From: foo@bar.com\nTo: bar@foo.com\nSubject: FOO BAR\n\nFoo foo bar bar?" }

  it "process an email without retry" do
    Email::Processor.expects(:process!).with(mail, retry_on_rate_limit: false, source: nil)
    Jobs::ProcessEmail.new.execute(mail: mail)
  end
end
