# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::ChatUsage do
  fab!(:date) { Date.new(2021).all_year }
  fab!(:user)
  fab!(:public_category) { Fabricate(:category) }
  fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
  fab!(:public_channel) { Fabricate(:category_channel, chatable: public_category) }
  fab!(:private_channel) { Fabricate(:category_channel, chatable: private_category) }

  before { SiteSetting.chat_enabled = true }

  describe ".call" do
    context "with messages in public and private channels" do
      before do
        5.times do
          Fabricate(
            :chat_message,
            chat_channel: public_channel,
            user: user,
            created_at: random_datetime,
          )
        end

        3.times do
          Fabricate(
            :chat_message,
            chat_channel: private_channel,
            user: user,
            created_at: random_datetime,
          )
        end
      end

      it "only includes public channels in favorite_channels" do
        result = call_report

        expect(result[:data][:favorite_channels].length).to eq(1)
        expect(result[:data][:favorite_channels].first[:channel_id]).to eq(public_channel.id)
        expect(result[:data][:favorite_channels].first[:message_count]).to eq(5)
      end

      it "includes all messages in total_messages count" do
        result = call_report

        expect(result[:data][:total_messages]).to eq(8)
      end
    end
  end
end
