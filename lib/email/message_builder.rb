# Builds a Mail::Mesage we can use for sending. Optionally supports using a template
# for the body and subject
module Email

  module BuildEmailHelper
    def build_email(*builder_args)
      builder = Email::MessageBuilder.new(*builder_args)
      headers(builder.header_args) if builder.header_args.present?
      mail(builder.build_args)
    end
  end

  class MessageBuilder

    def initialize(to, opts=nil)
      @to = to
      @opts = opts || {}
    end

    def subject
      subject = @opts[:subject]
      subject = I18n.t("#{@opts[:template]}.subject_template", template_args) if @opts[:template]
      subject
    end

    def body
      body = @opts[:body]
      body = I18n.t("#{@opts[:template]}.text_body_template", template_args) if @opts[:template]

      if @opts[:add_unsubscribe_link]
        body << "\n"
        body << I18n.t('unsubscribe_link', template_args)
      end

      body
    end

    def template_args
      @template_args ||= { site_name: SiteSetting.title,
                           base_url: Discourse.base_url,
                           user_preferences_url: "#{Discourse.base_url}/user_preferences" }.merge!(@opts)
    end

    def build_args
      mail_args = { to: @to,
                    subject: subject,
                    body: body,
                    charset: 'UTF-8' }

      mail_args[:from] = @opts[:from] || SiteSetting.notification_email

      if @opts[:from_alias]
        mail_args[:from] = "#{@opts[:from_alias]} <#{mail_args[:from]}>"
      end
      mail_args
    end

    def header_args
      result = {}
      if @opts[:add_unsubscribe_link]
        result['List-Unsubscribe'] = "<#{template_args[:user_preferences_url]}>" if @opts[:add_unsubscribe_link]
      end
      result
    end

  end

end
