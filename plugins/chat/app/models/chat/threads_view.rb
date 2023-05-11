# frozen_string_literal: true

module Chat
  class ThreadsView
    attr_reader :user, :channel, :threads

    def initialize(channel:, threads:, user:)
      @channel = channel
      @threads = threads
      @user = user
    end
  end
end
