require_dependency 'email/sender'

module Jobs

  # Asynchronously send an email
  class TestEmail < Jobs::Base

    sidekiq_options queue: 'critical'

    def execute(args)

      raise Discourse::InvalidParameters.new(:to_address) unless args[:to_address].present?

      message = TestMailer.send_test(args[:to_address])
      Email::Sender.new(message, :test_message).send
    end

  end

end
