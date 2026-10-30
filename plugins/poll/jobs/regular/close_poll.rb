# frozen_string_literal: true

module Jobs
  class ClosePoll < ::Jobs::Base
    def execute(args)
      poll = ::Poll.find_by(id: args[:poll_id])
      return if poll.nil? || poll.close_at.to_i != args[:close_at]

      DiscoursePoll::Poll.toggle_status(
        Discourse.system_user,
        poll.post_id,
        poll.name,
        "closed",
        false,
      )
    end
  end
end
