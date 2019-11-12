# frozen_string_literal: true

class EmailStyleUpdater

  attr_reader :errors

  def initialize(user)
    @user = user
    @errors = []
  end

  def update(attrs)
    if attrs.has_key?(:html) && !attrs[:html].include?('%{email_content}')
      @errors << I18n.t(
        'email_style.html_missing_placeholder',
        placeholder: '%{email_content}'
      )
    end

    if attrs.has_key?(:css)
      begin
        compiled_css = SassC::Engine.new(attrs[:css], style: :compressed).render
      rescue SassC::SyntaxError => e
        # @errors << I18n.t('email_style.css_syntax_error')
        @errors << e.message[0...(e.message.index("\n"))]
      end
    end

    return false unless @errors.empty?

    if attrs.has_key?(:html)
      if attrs[:html] == EmailStyle.default_template
        SiteSetting.remove_override!(:email_custom_template)
      else
        SiteSetting.email_custom_template = attrs[:html]
      end
    end

    if attrs.has_key?(:css)
      if attrs[:css] == EmailStyle.default_css
        SiteSetting.remove_override!(:email_custom_css)
        SiteSetting.remove_override!(:email_custom_css_compiled)
      else
        SiteSetting.email_custom_css = attrs[:css]
        SiteSetting.email_custom_css_compiled = compiled_css
      end
    end

    @errors.empty?
  end
end
