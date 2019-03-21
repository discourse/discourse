require_dependency 'email/sender'

module Jobs
  # Asynchronously send an email
  class TestEmail < Jobs::Base
    sidekiq_options queue: 'critical'

    def execute(args)
      unless args[:to_address].present?
        raise Discourse::InvalidParameters.new(:to_address)
      end

      message = TestMailer.send_test(args[:to_address])
      Email::Sender.new(message, :test_message).send
    end
  end
end
