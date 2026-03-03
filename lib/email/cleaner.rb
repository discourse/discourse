# frozen_string_literal: true

module Email
  class Cleaner
    def initialize(mail, remove_attachments: true, truncate: true, rejected: false)
      @mail = Mail.new(mail)
      @mail.charset = "UTF-8"
      # The default sort order may incorrectly put postscripts to the message
      # (e.g. such as those that might be appended by mailing lists as in
      # https://meta.discourse.org/t/377793/21) ahead of "real content"
      #
      # default is: "text/plain", "text/enriched", "text/html", "multipart/alternative"
      @mail.body.set_sort_order([])
      @remove_attachments = remove_attachments
      @truncate = truncate
      @rejected = rejected
    end

    def execute
      @mail.without_attachments! if @remove_attachments
      truncate! if @truncate
      remove_null_byte(@mail.to_s)
    end

    def self.delete_rejected!
      IncomingEmail.delete_by(
        "rejection_message IS NOT NULL AND created_at < ?",
        SiteSetting.delete_rejected_email_after_days.days.ago,
      )
    end

    private

    def truncate!
      parts.each do |part|
        part.body = part.body.decoded.truncate(truncate_limit, omission: "")
        # let the serialiser re-encode it with an appropriate format - leaving
        # the original one set tells Mail that the content is *already* encoded
        part.content_transfer_encoding = nil
      end
    end

    def parts
      @mail.multipart? ? @mail.parts : [@mail]
    end

    def truncate_limit
      @rejected ? SiteSetting.raw_rejected_email_max_length : SiteSetting.raw_email_max_length
    end

    def remove_null_byte(message)
      message.gsub!("\x00", "")
      message
    end
  end
end
