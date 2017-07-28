class RateLimiter

  # A mixin we can use on ActiveRecord Models to automatically rate limit them
  # based on a SiteSetting.
  #
  # It expects a SiteSetting called `rate_limit_create_{model_name}` where
  # `model_name` is the class name of your model, underscored.
  #
  module OnCreateRecord

    # Over write to define your own rate limiter
    def default_rate_limiter
      return @rate_limiter if @rate_limiter.present?

      limit_key = "create_#{self.class.name.underscore}"
      max_setting = if user && user.new_user? && SiteSetting.has_setting?("rate_limit_new_user_#{limit_key}")
        SiteSetting.send("rate_limit_new_user_#{limit_key}")
      else
        SiteSetting.send("rate_limit_#{limit_key}")
      end
      @rate_limiter = RateLimiter.new(user, limit_key, 1, max_setting)
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    # For the lifetime of this instance, don't enforce rate limits.
    def disable_rate_limits!
      @rate_limits_disabled = true
    end

    module ClassMethods
      def rate_limit(limiter_method = nil)

        limiter_method = limiter_method || :default_rate_limiter

        self.after_create do |*args|
          next if @rate_limits_disabled

          if rate_limiter = send(limiter_method)
            rate_limiter.performed!
            @performed ||= {}
            @performed[limiter_method] = true
          end
        end

        self.after_destroy do
          next if @rate_limits_disabled
          if rate_limiter = send(limiter_method)
            rate_limiter.rollback!
          end
        end

        self.after_rollback do
          next if @rate_limits_disabled
          if rate_limiter = send(limiter_method)
            if @performed.present? && @performed[limiter_method]
              rate_limiter.rollback!
              @performed[limiter_method] = false
            end
          end
        end

      end
    end

  end

end
