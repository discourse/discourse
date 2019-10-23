# frozen_string_literal: true

class EmailStyle
  include ActiveModel::Serialization

  attr_accessor :html, :css, :default_html, :default_css

  def id
    'email-style'
  end

  def html
    SiteSetting.email_custom_template.presence || default_html
  end

  def css
    SiteSetting.email_custom_css || default_css
  end

  def compiled_css
    SiteSetting.email_custom_css_compiled || self.class.default_css_compiled
  end

  def default_html
    self.class.default_template
  end

  def default_css
    self.class.default_css
  end

  def self.default_template
    @_default_template ||= File.read(
      File.join(Rails.root, 'app', 'views', 'email', 'default_template.html')
    )
  end

  def self.default_css
    ''
  end

  def self.default_css_compiled
    ''
  end
end
