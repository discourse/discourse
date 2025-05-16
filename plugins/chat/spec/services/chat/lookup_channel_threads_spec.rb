# frozen_string_literal: true

RSpec.describe ::Chat::LookupChannelThreads::Contract, type: :model do
  it { is_expected.to validate_presence_of(:channel_id) }
  it { is_expected.to allow_values(1, 0, nil, "a").for(:limit) }
  it do
    is_expected.not_to allow_values(::Chat::LookupChannelThreads::THREADS_LIMIT + 1).for(:limit)
  end

  describe "Limits" do
    subject(:contract) { described_class.new }

    context "when limit is not set" do
      it "defaults to a max value" do
        contract.validate
        expect(contract.limit).to eq(::Chat::LookupChannelThreads::THREADS_LIMIT)
      end
    end

    context "when limit is over max" do
      before { contract.limit = ::Chat::LookupChannelThreads::THREADS_LIMIT + 1 }

      it "sets limit to max" do
        contract.validate
        expect(contract.limit).to eq(::Chat::LookupChannelThreads::THREADS_LIMIT)
      end
    end

    context "when limit is allowed" do
      before { contract.limit = 5 }

      it "sets limit to the value" do
        contract.validate
        expect(contract.limit).to eq(5)
      end
    end
  end

  describe "Offsets" do
    subject(:contract) { described_class.new }

    context "when offset is not set" do
      it "defaults to zero" do
        contract.validate
        expect(contract.offset).to be_zero
      end
    end

    context "when offset is under 0" do
      before { contract.offset = -1 }

      it "sets offset to zero" do
        contract.validate
        expect(contract.offset).to be_zero
      end
    end

    context "when offset is allowed" do
      before { contract.offset = 5 }

      it "sets offset to the value" do
        contract.validate
        expect(contract.offset).to eq(5)
      end
    end
  end

  describe "#offset_query" do
    subject(:contract) { described_class.new }

    before do
      contract.limit = 10
      contract.offset = 5
    end

    it "returns the offset query string" do
      expect(contract.offset_query).to eq("offset=15")
    end
  end
end

RSpec.describe ::Chat::LookupChannelThreads do
  subject(:result) { described_class.call(params:, **dependencies) }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }

  let(:guardian) { Guardian.new(current_user) }
  let(:channel_id) { channel.id }
  let(:limit) { 10 }
  let(:offset) { 0 }
  let(:params) { { channel_id:, limit:, offset: } }
  let(:dependencies) { { guardian: } }

  context "when data is invalid" do
    let(:channel_id) { nil }

    it { is_expected.to fail_a_contract }
  end

  context "when channel doesn’t exist" do
    let(:channel_id) { -999 }

    it { is_expected.to fail_to_find_a_model(:channel) }
  end

  context "when channel threading is disabled" do
    before { channel.update!(threading_enabled: false) }

    it { is_expected.to fail_a_policy(:threading_enabled_for_channel) }
  end

  context "when channel cannot be previewed" do
    fab!(:channel) { Fabricate(:private_category_channel, threading_enabled: true) }

    it { is_expected.to fail_a_policy(:can_view_channel) }
  end

  context "when channel has no threads" do
    it { is_expected.to fail_to_find_a_model(:threads) }
  end

  context "when everything is ok" do
    fab!(:threads) { Fabricate.times(3, :chat_thread, channel:) }

    before do
      channel.add(current_user)
      threads.each.with_index do |t, index|
        t.original_message.update!(created_at: (index + 1).weeks.ago)
        t.update!(replies_count: 2)
        t.add(current_user)
      end
      allow(Chat::Action::FetchThreads).to receive(:call).with(
        user_id: current_user.id,
        channel_id: channel.id,
        limit:,
        offset:,
      ).and_return(threads)
    end

    it { is_expected.to run_successfully }

    it "returns the threads" do
      expect(result.threads).to eq(threads)
    end

    it "returns threads tracking" do
      expect(result.tracking).to eq(
        ::Chat::TrackingStateReportQuery.call(
          guardian: guardian,
          thread_ids: threads.map(&:id),
          include_threads: true,
        ).thread_tracking,
      )
    end

    it "returns memberships" do
      expect(result.memberships).to eq(
        ::Chat::UserChatThreadMembership.where(
          thread_id: threads.map(&:id),
          user_id: current_user.id,
        ),
      )
    end

    it "returns participants" do
      expect(result.participants).to eq(
        ::Chat::ThreadParticipantQuery.call(thread_ids: threads.map(&:id)),
      )
    end

    it "returns a url with the correct params" do
      expect(result.load_more_url).to eq("/chat/api/channels/#{channel.id}/threads?offset=10")
    end
  end
end
