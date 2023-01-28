# frozen_string_literal: true

RSpec.describe(Chat::Service::UpdateChannelStatus) do
  let(:guardian) { Guardian.new(current_user) }

  context "when status is given as a string" do
    fab!(:current_user) { Fabricate(:admin) }
    fab!(:channel) { Fabricate(:chat_channel) }

    subject(:result) { described_class.call(guardian: guardian, channel: channel, status: "open") }

    it "converts status to a symbol" do
      expect(result.status).to eq(:open)
    end
  end
end
