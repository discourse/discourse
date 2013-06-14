require 'spec_helper'
require 'email/receiver'

describe Email::Receiver do


  describe 'invalid key' do
    let(:incoming) { Email::IncomingMessage.new('asdf', 'hello') }

    it "returns unprocessable for nil message" do
      expect(Email::Receiver.new(nil).process).to eq(Email::Receiver.results[:unprocessable])
    end

    it "returns unprocessable for a made up key" do
      expect(Email::Receiver.new(incoming).process).to eq(Email::Receiver.results[:unprocessable])
    end
  end

end
