require_dependency 'email/message_builder'

class RejectionMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  DISALLOWED_TEMPLATE_ARGS = [:to, :from, :base_url,
                              :user_preferences_url,
                              :include_respond_instructions, :html_override,
                              :add_unsubscribe_link, :respond_instructions,
                              :style, :body, :post_id, :topic_id, :subject,
                              :template, :allow_reply_by_email,
                              :private_reply, :from_alias]

  # Send an email rejection message.
  #
  # template - i18n key under system_messages
  # message_from - Who to send the rejection messsage to
  # template_args - arguments to pass to i18n for interpolation into the message
  #     Certain keys are disallowed in template_args to avoid confusing the
  #     BuildEmailHelper. You can see the list in DISALLOWED_TEMPLATE_ARGS.
  def send_rejection(template, message_from, template_args)
    if template_args.keys.any? { |k| DISALLOWED_TEMPLATE_ARGS.include? k }
      raise ArgumentError.new('Reserved key in template arguments')
    end

    build_email(message_from, template_args.merge(template: "system_messages.#{template}"))
  end

end
