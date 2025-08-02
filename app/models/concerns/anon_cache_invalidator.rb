# frozen_string_literal: true

module AnonCacheInvalidator
  extend ActiveSupport::Concern

  included do
    after_destroy { Site.clear_anon_cache! }

    after_save { Site.clear_anon_cache! }
  end
end
