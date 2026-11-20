# frozen_string_literal: true

class Rtl
  LOCALES = %w[ar fa_IR he ug ur]

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def enabled?
    (user&.effective_locale || I18n.locale).to_s.in?(LOCALES)
  end

  def css_class
    enabled? ? "rtl" : ""
  end
end
