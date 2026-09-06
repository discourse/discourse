module Holidays
  module Definition
    module Repository
      class CustomMethods
        def initialize
          @custom_methods = {}
        end

        # This performs a merge that overwrites any conflicts.
        # While this is not ideal I'm leaving it as-is since I have no
        # evidence of any current definitions that will cause an issue.
        #
        # FIXME: this should probably return an error if a method with the
        # same ID already exists.
        def add(new_custom_methods)
          raise ArgumentError if new_custom_methods.nil?
          @custom_methods.merge!(new_custom_methods)
        end

        def find(method_id)
          raise ArgumentError if method_id.nil? || method_id.empty?
          @custom_methods[method_id]
        end
      end
    end
  end
end
