require 'spec_helper'
require 'email/receiver'

describe Email::IncomingMessage do

  let(:message) { Email::IncomingMessage.new("asdf", "hello\n\n> how are you?") }

  it "returns the reply_key" do
    expect(message.reply_key).to eq("asdf")
  end

  it "extracts the reply" do
    expect(message.reply).to eq("hello")
  end

end
