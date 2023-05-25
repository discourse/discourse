# frozen_string_literal: true

module Chat
  class ThreadsView
    attr_reader :user, :channel, :threads, :tracking

    def initialize(channel:, threads:, user:, tracking:)
      @channel = channel
      @threads = threads
      @user = user
      @tracking = tracking
    end
  end
end
