# frozen_string_literal: true

RSpec.describe ::Chat::LookupUserThreads do
  subject(:result) { described_class.call(params:, **dependencies) }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1, with_replies: 1) }

  let(:guardian) { Guardian.new(current_user) }
  let(:channel_id) { channel_1.id }
  let(:limit) { 10 }
  let(:offset) { 0 }
  let(:params) { { limit:, offset: } }
  let(:dependencies) { { guardian: } }

  before do
    channel_1.add(current_user)
    thread_1.add(current_user)
  end

  context "when all steps pass" do
    it { is_expected.to run_successfully }

    it "returns threads" do
      expect(result.threads).to eq([thread_1])
    end

    it "limits results by default" do
      Fabricate
        .times(11, :chat_thread, channel: channel_1, with_replies: 1)
        .each { |thread| thread.add(current_user) }

      expect(result.threads.length).to eq(10)
    end

    it "can limit results" do
      params[:limit] = 1

      Fabricate
        .times(2, :chat_thread, channel: channel_1, with_replies: 1)
        .each { |thread| thread.add(current_user) }

      expect(result.threads.length).to eq(params[:limit])
    end

    it "limits to 1 at least" do
      params[:limit] = 0

      Fabricate(:chat_thread, channel: channel_1, with_replies: 1).tap do |thread|
        thread.add(current_user)
      end

      expect(result.threads.length).to eq(1)
    end

    it "has a max limit" do
      params[:limit] = 11

      Fabricate
        .times(11, :chat_thread, channel: channel_1, with_replies: 1)
        .each { |thread| thread.add(current_user) }

      expect(result.threads.length).to eq(10)
    end

    it "can offset" do
      params[:offset] = 1

      Chat::Thread.destroy_all
      threads =
        Fabricate
          .times(2, :chat_thread, channel: channel_1, with_replies: 1)
          .each { |thread| thread.add(current_user) }

      # 0 because we sort by last_message.created_at, so the last created thread is the first one
      expect(result.threads).to eq([threads[0]])
    end

    it "has a min offset" do
      params[:offset] = -99

      Chat::Thread.destroy_all
      Fabricate
        .times(2, :chat_thread, channel: channel_1, with_replies: 1)
        .each { |thread| thread.add(current_user) }

      # 0 because we sort by last_message.created_at, so the last created thread is the first one
      expect(result.threads.length).to eq(2)
    end

    it "fetches tracking" do
      expect(result.tracking).to eq(
        ::Chat::TrackingStateReportQuery.call(
          guardian: current_user.guardian,
          thread_ids: [thread_1.id],
          include_threads: true,
        ).thread_tracking,
      )
    end

    it "fetches memberships" do
      expect(result.memberships).to eq([thread_1.membership_for(current_user)])
    end

    it "fetches participants" do
      expect(result.participants).to eq(
        ::Chat::ThreadParticipantQuery.call(thread_ids: [thread_1.id]),
      )
    end

    it "builds a load_more_url" do
      expect(result.load_more_url).to eq("/chat/api/me/threads?limit=10&offset=10")
    end
  end

  it "doesn't return threads with no replies" do
    Fabricate(:chat_thread, channel: channel_1).tap { _1.add(current_user) }

    expect(result.threads).to eq([thread_1])
  end

  it "doesn't return threads with no membership" do
    Fabricate(:chat_thread, channel: channel_1, with_replies: 1)

    expect(result.threads).to eq([thread_1])
  end

  it "doesn't return threads when the channel has not threading enabled" do
    channel_1.update!(threading_enabled: false)

    expect(result.threads).to eq([])
  end

  it "doesn't return muted threads" do
    thread_1.membership_for(current_user).update!(
      notification_level: ::Chat::UserChatThreadMembership.notification_levels[:muted],
    )

    expect(result.threads).to eq([])
  end

  it "doesn't return threads when the channel it not open" do
    channel_1.update!(status: Chat::Channel.statuses[:closed])

    expect(result.threads).to eq([])
  end

  it "returns threads from muted channels" do
    channel_1.membership_for(current_user).update!(muted: true)

    expect(result.threads).to eq([thread_1])
  end
end
