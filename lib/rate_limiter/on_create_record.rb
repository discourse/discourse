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
      max_setting = SiteSetting.send("rate_limit_#{limit_key}")
      @rate_limiter = RateLimiter.new(user, limit_key, 1, max_setting)
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def rate_limit(limiter_method=nil)

        limiter_method = limiter_method || :default_rate_limiter

        # Use lambda blocks in these callbacks so that return works properly
        # See https://github.com/rails/rails/pull/13271

        self.after_create &lambda {
          rate_limiter = send(limiter_method)
          return unless rate_limiter.present?

          rate_limiter.performed!
          @performed ||= {}
          @performed[limiter_method] = true
        }

        self.after_destroy &lambda {
          rate_limiter = send(limiter_method)
          return unless rate_limiter.present?

          rate_limiter.rollback!
        }

        self.after_rollback &lambda {
          rate_limiter = send(limiter_method)
          return unless rate_limiter.present?

          if @performed.present? && @performed[limiter_method]
            rate_limiter.rollback!
            @performed[limiter_method] = false
          end
        }

      end
    end

  end

end
