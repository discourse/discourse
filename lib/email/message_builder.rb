# Builds a Mail::Message we can use for sending. Optionally supports using a template
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

      @template_args = {
        site_name: SiteSetting.email_prefix.presence || SiteSetting.title,
        base_url: Discourse.base_url,
        user_preferences_url: "#{Discourse.base_url}/my/preferences",
      }.merge!(@opts)

      if @template_args[:url].present?
        if @opts[:include_respond_instructions] == false
          @template_args[:respond_instructions] = ''
        else
          @template_args[:respond_instructions] = if allow_reply_by_email?
            I18n.t('user_notifications.reply_by_email', @template_args)
          else
            I18n.t('user_notifications.visit_link_to_respond', @template_args)
          end
        end
      end
    end

    def subject
      if @opts[:use_site_subject]
        subject = String.new(SiteSetting.email_subject)
        subject.gsub!("%{site_name}", @template_args[:site_name])
        subject.gsub!("%{optional_re}", @opts[:add_re_to_subject] ? I18n.t('subject_re', template_args) : '')
        subject.gsub!("%{optional_pm}", @opts[:private_reply] ? I18n.t('subject_pm', template_args) : '')
        subject.gsub!("%{optional_cat}", @template_args[:show_category_in_subject] ? "[#{@template_args[:show_category_in_subject]}] " : '')
        subject.gsub!("%{topic_title}", @template_args[:topic_title]) if @template_args[:topic_title] # must be last for safety
      else
        subject = @opts[:subject]
        subject = I18n.t("#{@opts[:template]}.subject_template", template_args) if @opts[:template]
      end
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
        html_override.gsub!("%{unsubscribe_link}", unsubscribe_link)
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
      body = I18n.t("#{@opts[:template]}.text_body_template", template_args).dup if @opts[:template]

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

    def private_reply?
      allow_reply_by_email? && @opts[:private_reply]
    end

    def from_value
      return @from_value if @from_value
      @from_value = @opts[:from] || SiteSetting.notification_email
      @from_value = alias_email(@from_value)
    end

    def reply_by_email_address
      return @reply_by_email_address if @reply_by_email_address
      return nil unless SiteSetting.reply_by_email_address.present?

      @reply_by_email_address = SiteSetting.reply_by_email_address.dup
      @reply_by_email_address.gsub!("%{reply_key}", reply_key)
      @reply_by_email_address = if private_reply?
                                  alias_email(@reply_by_email_address)
                                else
                                  site_alias_email(@reply_by_email_address)
                                end
    end

    def alias_email(source)
      return source if @opts[:from_alias].blank? && SiteSetting.email_site_title.blank?
      if !@opts[:from_alias].blank?
        "#{Email.cleanup_alias(@opts[:from_alias])} <#{source}>"
      else
        "#{Email.cleanup_alias(SiteSetting.email_site_title)} <#{source}>"
      end
    end

    def site_alias_email(source)
      "#{Email.cleanup_alias(SiteSetting.email_site_title.presence || SiteSetting.title)} <#{source}>"
    end

  end

end
