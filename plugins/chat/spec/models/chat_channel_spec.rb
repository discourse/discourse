# frozen_string_literal: true

RSpec.describe ChatChannel do
  fab!(:category_channel) { Fabricate(:category_channel) }
  fab!(:dm_channel) { Fabricate(:direct_message_channel) }

  describe "#relative_url" do
    context "when the slug is nil" do
      it "uses a - instead" do
        category_channel.slug = nil
        expect(category_channel.relative_url).to eq("/chat/channel/#{category_channel.id}/-")
      end
    end

    context "when the slug is not nil" do
      before do
        category_channel.update!(slug: "some-cool-channel")
      end

      it "includes the slug for the channel" do
        expect(category_channel.relative_url).to eq("/chat/channel/#{category_channel.id}/some-cool-channel")
      end
    end
  end
end
