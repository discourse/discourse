# Builds a Mail::Mesage we can use for sending. Optionally supports using a template
# for the body and subject
module Email

  module BuildEmailHelper
    def build_email(*builder_args)
      builder = Email::MessageBuilder.new(*builder_args)
      headers(builder.header_args) if builder.header_args.present?
      mail(builder.build_args).tap { |message|
        if message and h = builder.html_part
          message.html_part = h
        end
      }
    end
  end

  class MessageBuilder
    attr_reader :template_args

    def initialize(to, opts=nil)
      @to = to
      @opts = opts || {}

      @template_args = {site_name: SiteSetting.title,
                        base_url: Discourse.base_url,
                        user_preferences_url: "#{Discourse.base_url}/user_preferences" }.merge!(@opts)

      if @template_args[:url].present?
        @template_args[:respond_instructions] =
          if allow_reply_by_email?
            I18n.t('user_notifications.reply_by_email', @template_args)
          else
            I18n.t('user_notifications.visit_link_to_respond', @template_args)
          end
      end
    end

    def subject
      subject = @opts[:subject]
      subject = I18n.t("#{@opts[:template]}.subject_template", template_args) if @opts[:template]
      subject
    end

    def html_part
      return unless html_override = @opts[:html_override]
      if @opts[:add_unsubscribe_link]

        if response_instructions = @template_args[:respond_instructions]
          respond_instructions = PrettyText.cook(response_instructions).html_safe
          html_override.gsub!("%{respond_instructions}", respond_instructions)
        end

        unsubscribe_link = PrettyText.cook(I18n.t('unsubscribe_link', template_args)).html_safe
        html_override.gsub!("%{unsubscribe_link}",unsubscribe_link)
      end

      styled = Email::Styles.new(html_override)
      styled.format_basic

      if style = @opts[:style]
        styled.send "format_#{style}"
      end

      Mail::Part.new do
        content_type 'text/html; charset=UTF-8'
        body styled.to_html
      end
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

    def build_args
      { to: @to,
        subject: subject,
        body: body,
        charset: 'UTF-8',
        from: from_value }
    end

    def header_args
      result = {}
      if @opts[:add_unsubscribe_link]
        result['List-Unsubscribe'] = "<#{template_args[:user_preferences_url]}>" if @opts[:add_unsubscribe_link]
      end

      result['X-Discourse-Post-Id'] = @opts[:post_id].to_s if @opts[:post_id]
      result['X-Discourse-Topic-Id'] = @opts[:topic_id].to_s if @opts[:topic_id]

      if allow_reply_by_email?
        result['X-Discourse-Reply-Key'] = reply_key
        result['Reply-To'] = reply_by_email_address
      else
        result['Reply-To'] = from_value
      end

      result.merge(MessageBuilder.custom_headers(SiteSetting.email_custom_headers))
    end

    def self.custom_headers(string)
      result = {}
      string.split('|').each { |item|
        header = item.split(':', 2)
        if header.length == 2
          name = header[0].strip
          value = header[1].strip
          result[name] = value if name.length > 0 && value.length > 0
        end
      } unless string.nil?
      result
    end


    protected

    def reply_key
      @reply_key ||= SecureRandom.hex(16)
    end

    def allow_reply_by_email?
      SiteSetting.reply_by_email_enabled? &&
      reply_by_email_address.present? &&
      @opts[:allow_reply_by_email]
    end

    def from_value
      return @from_value if @from_value
      @from_value = @opts[:from] || SiteSetting.notification_email
      @from_value = alias_email(@from_value)
      @from_value
    end

    def reply_by_email_address
      return @reply_by_email_address if @reply_by_email_address
      return nil unless SiteSetting.reply_by_email_address.present?

      @reply_by_email_address = SiteSetting.reply_by_email_address.dup
      @reply_by_email_address.gsub!("%{reply_key}", reply_key)
      @reply_by_email_address = alias_email(@reply_by_email_address)

      @reply_by_email_address
    end

    def alias_email(source)
      return source if @opts[:from_alias].blank?
      "#{@opts[:from_alias]} <#{source}>"
    end

  end

end
