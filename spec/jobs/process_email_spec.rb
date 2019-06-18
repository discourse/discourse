# frozen_string_literal: true

require "rails_helper"

describe Jobs::ProcessEmail do

  let(:mail) { "From: foo@bar.com\nTo: bar@foo.com\nSubject: FOO BAR\n\nFoo foo bar bar?" }

  it "process an email without retry" do
    Email::Processor.expects(:process!).with(mail, false)
    Jobs::ProcessEmail.new.execute(mail: mail)
  end

end
