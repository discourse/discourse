# frozen_string_literal: true

RSpec.describe HashtagAutocompleteService do
  subject(:service) { described_class.new(guardian) }

  before { SiteSetting.chat_enabled = true }

  describe ".enabled_data_sources" do
    it "only returns data sources that are enabled" do
      expect(HashtagAutocompleteService.enabled_data_sources).to include(
        Chat::ChannelHashtagDataSource,
      )
    end
  end
end
