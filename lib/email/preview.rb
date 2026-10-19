# frozen_string_literal: true

module Email
  class Preview
    TYPES = {
      "digest" => :digest,
      "password_reset" => :forgot_password,
      "password_reset_code" => :email_login_code,
      "email_login_code" => :email_login_code,
      "signup" => :signup,
      "activation_reminder" => :activation_reminder,
      "email_login" => :email_login,
      "admin_login" => :admin_login,
      "account_created" => :account_created,
      "confirm_new_email" => :confirm_new_email,
      "test_email" => :test_message,
    }.freeze
    TEMPLATE_PREFIX = "template:"
    PASSWORD_RESET_TOKEN = "preview-password-reset-token"
    EMAIL_TOKEN = "preview-email-token"
    LOGIN_CODE = "PREVIEW"

    attr_reader :locale, :theme_id

    def self.message_types
      TYPES.keys.map do |type|
        { id: type, title: I18n.t("admin_js.admin.email.preview_types.#{type}") }
      end
    end

    def self.email_templates
      Admin::EmailTemplatesController.email_keys.map do |key|
        { id: key, title: AdminEmailTemplateSerializer.new(key).title }
      end
    end

    def self.branding_themes
      Theme
        .where(component: false)
        .where("id > 0")
        .includes(:remote_theme)
        .filter_map do |theme|
          { id: theme.id, title: theme.name } if theme.enabled? && theme.supported?
        end
    end

    def initialize(user:, email_type: nil, locale: nil, since: nil, theme_id: nil)
      @user = user
      @email_type = email_type.presence || "digest"
      @locale = locale.presence || user.effective_locale
      @since = since
      @theme_id = theme_id.presence
      if LocaleSiteSetting.supported_locales.exclude?(@locale)
        raise Discourse::InvalidParameters.new(:locale)
      end
      if !TYPES.key?(@email_type) &&
           (!template_key || Admin::EmailTemplatesController.email_keys.exclude?(template_key))
        raise Discourse::InvalidParameters.new(:email_type)
      end
      if @email_type == "digest" && @since.blank?
        raise Discourse::InvalidParameters.new(:last_seen_at)
      end
      if @theme_id
        theme = Theme.find_by(id: @theme_id)
        if !theme || theme.id < 0 || theme.component || !theme.enabled? || !theme.supported?
          raise Discourse::InvalidParameters.new(:theme_id)
        end
        @theme_id = theme.id
      end
    end

    def message
      @message ||= build_message
    end

    def empty?
      message.body.to_s.blank? && message.text_part&.body.to_s.blank? &&
        message.html_part&.body.to_s.blank?
    end

    def renderer
      @renderer ||=
        Email::Renderer.new(
          message,
          locale: locale,
          theme_id: theme_id,
          preview_theme: theme_id.present?,
        )
    end

    private

    def template_key
      @email_type.delete_prefix(TEMPLATE_PREFIX) if @email_type.start_with?(TEMPLATE_PREFIX)
    end

    def build_message
      options = { locale:, theme_id:, preview_theme: theme_id.present? }
      if template_key
        return(
          TestMailer.send_template_preview(
            @user.email,
            subject: template_value("#{template_key}.subject_template"),
            body: template_value("#{template_key}.text_body_template"),
            **options,
          )
        )
      end

      case @email_type
      when "digest"
        UserNotifications.digest(@user, since: @since, skip_unsubscribe_links: true, **options)
      when "password_reset"
        UserNotifications.forgot_password(@user, email_token: PASSWORD_RESET_TOKEN, **options)
      when "password_reset_code", "email_login_code"
        EmailLoginCodeMailer.send_code(
          @user.email,
          LOGIN_CODE,
          password_reset: @email_type == "password_reset_code",
          **options,
        )
      when "test_email"
        TestMailer.send_test(@user.email, **options)
      else
        UserNotifications.public_send(
          TYPES.fetch(@email_type),
          @user,
          email_token: EMAIL_TOKEN,
          **options,
        )
      end
    end

    def template_value(key)
      value = I18n.t(key, locale: locale)
      value = value[:other] || value["other"] if value.is_a?(Hash)
      raise Discourse::InvalidParameters.new(:email_type) if !value.is_a?(String)
      value
    end
  end
end
