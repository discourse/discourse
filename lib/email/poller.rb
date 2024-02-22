# frozen_string_literal: true

module Email
  class Poller
    # To be implemented by concrete classes.
    # This function takes as input a function that processes the incoming email.
    # The function passed as argument should take as an argument the MIME string of the email.
    # An example of function to pass is `process_popmail` in `app/jobs/scheduled/poll_mailbox.rb`
    def poll_mailbox(process_cb)
      raise NotImplementedError
    end

    # Child class can override this
    def enabled?
      true
    end
  end
end
