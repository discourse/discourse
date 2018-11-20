module Jobs

  class ClosePoll < Jobs::Base

    def execute(args)
      DiscoursePoll::Poll.toggle_status(args[:post_id], args[:poll_name], "closed", -1)
    end

  end

end
