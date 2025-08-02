# frozen_string_literal: true

class EmailStyle
  include ActiveModel::Serialization

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

  def self.default_template
    @_default_template ||=
      File.read(File.join(Rails.root, "app", "views", "email", "default_template.html"))
  end

  def self.default_css
    ""
  end
end
