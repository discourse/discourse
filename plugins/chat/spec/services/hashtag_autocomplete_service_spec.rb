# frozen_string_literal: true

RSpec.describe HashtagAutocompleteService do
  subject(:service) { described_class.new(guardian) }

  fab!(:channel1) { Fabricate(:chat_channel, name: "Music Lounge", slug: "music") }
  fab!(:channel2) { Fabricate(:chat_channel, name: "Random", slug: "random") }

  fab!(:admin)
  let(:guardian) { Guardian.new(admin) }

  describe ".enabled_data_sources" do
    it "only returns data sources that are enabled" do
      expect(HashtagAutocompleteService.enabled_data_sources).to include(
        Chat::ChannelHashtagDataSource,
      )
    end
  end

  describe "#lookup" do
    it "returns hashtags for channels" do
      result = service.lookup(%w[music::channel random::channel], ["channel"])
      expect(result[:channel].map(&:slug)).to contain_exactly("music", "random")
    end
  end
end
