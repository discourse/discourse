# frozen_string_literal: true

class EmailStyleUpdater

  attr_reader :errors

  def initialize(user)
    @user = user
    @errors = []
  end

  def update(attrs)
    if attrs.has_key?(:html)
      if attrs[:html] == EmailStyle.default_template
        SiteSetting.remove_override!(:email_custom_template)
      else
        if !attrs[:html].include?('%{email_content}')
          @errors << I18n.t(
            'email_style.html_missing_placeholder',
            placeholder: '%{email_content}'
          )
        else
          SiteSetting.email_custom_template = attrs[:html]
        end
      end
    end

    if attrs.has_key?(:css)
      if attrs[:css] == EmailStyle.default_css
        SiteSetting.remove_override!(:email_custom_css)
      else
        SiteSetting.email_custom_css = attrs[:css]
      end
    end

    @errors.empty?
  end
end
