# frozen_string_literal: true

module DiscourseAi
  module Translation
    module LocalizableQuota
      extend ActiveSupport::Concern

      MAX_QUOTA_PER_DAY = 2

      class_methods do
        def has_relocalize_quota?(model, locale, skip_incr: false)
          return false if get_relocalize_quota(model, locale).to_i >= MAX_QUOTA_PER_DAY

          incr_relocalize_quota(model, locale) unless skip_incr
          true
        end

        def relocalize_key(model, locale)
          "#{model_name}_relocalized_#{model.id}_#{locale}"
        end

        private

        def get_relocalize_quota(model, locale)
          Discourse.redis.get(relocalize_key(model, locale)).to_i || 0
        end

        def incr_relocalize_quota(model, locale)
          key = relocalize_key(model, locale)

          if (count = get_relocalize_quota(model, locale)).zero?
            Discourse.redis.set(key, 1, ex: 1.day.to_i)
          else
            ttl = Discourse.redis.ttl(key)
            incr = count.to_i + 1
            Discourse.redis.set(key, incr, ex: ttl)
          end
        end
      end
    end
  end
end
