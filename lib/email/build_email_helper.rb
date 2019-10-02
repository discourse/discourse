# frozen_string_literal: true

module Email
  module BuildEmailHelper
    def build_email(*builder_args)
      builder = Email::MessageBuilder.new(*builder_args)
      headers(builder.header_args) if builder.header_args.present?
      mail(builder.build_args).tap { |message|
        if message && h = builder.html_part
          message.html_part = h
        end
      }
    end
  end
end
