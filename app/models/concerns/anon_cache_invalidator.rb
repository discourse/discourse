module AnonCacheInvalidator
  extend ActiveSupport::Concern

  included do
    after_destroy do
      Site.clear_anon_cache!
    end

    after_save do
      Site.clear_anon_cache!
    end
  end
end
