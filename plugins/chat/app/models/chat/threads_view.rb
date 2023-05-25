# frozen_string_literal: true

module Chat
  class ThreadsView
    attr_reader :user, :channel, :threads, :tracking, :memberships

    def initialize(channel:, threads:, user:, tracking:, memberships:)
      @channel = channel
      @threads = threads
      @user = user
      @tracking = tracking
      @memberships = memberships
    end
  end
end
