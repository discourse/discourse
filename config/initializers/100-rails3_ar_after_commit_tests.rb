# Allow after commits to work in test mode
if Rails.env.test?

  class ActiveRecord::Base
    class << self
      def after_commit(*args, &block)
        opts = args.extract_options! || {}

        case opts[:on]
        when :create
          after_create(*args, &block)
        when :update
          after_update(*args, &block)
        when :destroy
          after_destroy(*args, &block)
        else
          after_save(*args, &block)
        end
      end
    end
  end

end
