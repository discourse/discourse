# frozen_string_literal: true

RSpec.describe Chat::HomepageChannelSiteSetting do
  fab!(:channel_1) { Fabricate(:category_channel, name: "General") }

  it "offers public channels" do
    expect(described_class.values).to include({ name: "General", value: channel_1.id })
    expect(described_class.translate_names?).to eq(false)
  end

  it "does not offer direct message channels" do
    dm_channel = Fabricate(:direct_message_channel)

    expect(described_class.values.map { |v| v[:value] }).not_to include(dm_channel.id)
  end

  it "does not offer archived channels" do
    channel_1.update!(status: :archived)

    expect(described_class.values).to be_empty
  end

  it "validates values" do
    expect(described_class.valid_value?("")).to eq(true)
    expect(described_class.valid_value?(channel_1.id)).to eq(true)
    expect(described_class.valid_value?(-1)).to eq(false)
  end
end
