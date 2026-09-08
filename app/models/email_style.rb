# frozen_string_literal: true

class EmailStyle
  include ActiveModel::Serialization

  class << self
    def default_template
      @_default_template ||=
        File.read(Rails.root.join("app/views/email/default_template.html").to_s)
    end

    def default_css
      ""
    end
  end

  def id
    "email-style"
  end

  def html
    SiteSetting.email_custom_template.presence || default_html
  end

  def css
    SiteSetting.email_custom_css || default_css
  end

  def compiled_css
    SiteSetting.email_custom_css_compiled.presence || css
  end

  def default_html
    self.class.default_template
  end

  def default_css
    self.class.default_css
  end
end
