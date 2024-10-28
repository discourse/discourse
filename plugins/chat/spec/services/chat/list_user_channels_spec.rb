# frozen_string_literal: true

RSpec.describe Chat::ListUserChannels do
  subject(:result) { described_class.call(params:, **dependencies) }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }

  let(:guardian) { Guardian.new(current_user) }
  let(:params) { {} }
  let(:dependencies) { { guardian: } }

  before { channel_1.add(current_user) }

  it { is_expected.to run_successfully }

  it "returns the structured data" do
    expect(result.structured[:post_allowed_category_ids]).to eq(nil)
    expect(result.structured[:unread_thread_overview]).to eq({})
    expect(result.structured[:memberships].to_a).to eq([channel_1.membership_for(current_user)])
    expect(result.structured[:public_channels]).to eq([channel_1])
    expect(result.structured[:direct_message_channels]).to eq([])
    expect(result.structured[:tracking].channel_tracking[channel_1.id]).to eq(
      { mention_count: 0, unread_count: 0, watched_threads_unread_count: 0 },
    )
  end

  context "when the category is restricted and user has readonly permissions" do
    fab!(:group_1) { Fabricate(:group) }
    fab!(:private_channel_1) { Fabricate(:private_category_channel, group: group_1) }

    before do
      private_channel_1.chatable.category_groups.first.update!(
        permission_type: CategoryGroup.permission_types[:readonly],
      )
      group_1.add(current_user)
      private_channel_1.add(current_user)
    end

    it "doesn't list the associated channel" do
      expect(result.structured[:public_channels]).to contain_exactly(channel_1)
    end
  end

  context "when the category is restricted and user has permissions" do
    fab!(:group_1) { Fabricate(:group) }
    fab!(:private_channel_1) { Fabricate(:private_category_channel, group: group_1) }

    before do
      group_1.add(current_user)
      private_channel_1.add(current_user)
    end

    it "lists the associated channel" do
      expect(result.structured[:public_channels]).to contain_exactly(channel_1, private_channel_1)
    end
  end

  it "doesn't return dm channels from other users" do
    Fabricate(:direct_message_channel)

    expect(result.structured[:direct_message_channels]).to eq([])
  end

  it "returns dm channels you are part of" do
    dm_channel = Fabricate(:direct_message_channel, users: [current_user])

    expect(result.structured[:direct_message_channels]).to eq([dm_channel])
  end

  it "doesnt return channels with destroyed chatable" do
    dm_channel = Fabricate(:direct_message_channel, users: [current_user])
    dm_channel.chatable.destroy!
    channel_1.chatable.destroy!

    expect(result.structured[:direct_message_channels]).to eq([])
    expect(result.structured[:public_channels]).to eq([])
  end
end
