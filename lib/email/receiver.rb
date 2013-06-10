#
# Handles an incoming message
#
require_dependency 'email/incoming_message'

module Email
  class Receiver

    def self.results
      @results ||= Enum.new(:unprocessable)
    end

    def initialize(incoming_message)
      @incoming_message = incoming_message
    end

    def process

      if @incoming_message.blank? || @incoming_message.reply_key.blank?
        return Email::Receiver.results[:unprocessable]
      end

      log = EmailLog.where(reply_key: @incoming_message.reply_key).first
      return Email::Receiver.results[:unprocessable] if log.blank?

      nil
    end

  end
end
