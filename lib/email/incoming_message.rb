module Email

  class IncomingMessage

    attr_reader :reply_key,
                :body_plain

    def initialize(reply_key, body)
      @reply_key = reply_key
      @body = body
    end

    def reply
      @reply ||= EmailReplyParser.read(@body).visible_text
    end

  end

end