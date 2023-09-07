# frozen_string_literal: true

module Chat
  class ThreadsView
    attr_reader :user,
                :channel,
                :threads,
                :tracking,
                :memberships,
                :load_more_url,
                :threads_participants

    def initialize(
      channel:,
      threads:,
      user:,
      tracking:,
      memberships:,
      load_more_url:,
      threads_participants:
    )
      @channel = channel
      @threads = threads
      @user = user
      @tracking = tracking
      @memberships = memberships
      @load_more_url = load_more_url
      @threads_participants = threads_participants
    end
  end
end
