# see: https://github.com/rails/rails/issues/32995
#
# Rails 5.2 forces us to add Arel.sql to #order and #pluck
# Discourse is very SQL heavy and this makes the code much more
# verbose and confusing, especially since it is not enforced for
# #group, #join and many other relation methods
# For the time being we monkey patch this away, longer term we
# hope Rails will allow us for this to be optional

module ActiveRecord
  module AttributeMethods
    module ClassMethods
      def enforce_raw_sql_whitelist(*args)
        return
      end
    end
  end
end
