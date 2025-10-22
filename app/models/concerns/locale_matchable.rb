# frozen_string_literal: true

module LocaleMatchable
  extend ActiveSupport::Concern

  included do
    scope :matching_locale,
          ->(locale) do
            regionless_locale = locale.to_s.split("_").first
            where("locale LIKE ?", "#{regionless_locale}%")
          end
  end
end
