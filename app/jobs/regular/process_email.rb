module Jobs

  class ProcessEmail < Jobs::Base
    sidekiq_options retry: 3

    def execute(args)
      Email::Processor.process!(args[:mail], false)
    end

    sidekiq_retries_exhausted do |msg|
      Rails.logger.warn("Incoming email could not be processed after 3 retries.\n\n#{msg["args"][:mail]}")
    end

  end

end
