# frozen_string_literal: true

# The JSON gem's Object#to_json method just converts objects to strings using #to_s
# when it doesn't know how to serialize them. This is problematic because Rails/ActiveSupport
# relies on #as_json to provide JSON-serializable representations.
#
# When Oj was used, Oj::Rails.set_encoder() made the JSON encoding respect #as_json.
# This patch restores that behavior for the standard JSON gem.
#
# Without this patch, JSON.dump(ActiveModel::Serializer.new(obj)) would output
# something like "#<SomeSerializer:0x00007f...>" instead of the actual JSON.

module JSON
  module Ext
    module Generator
      module GeneratorMethods
        module Object
          def to_json(state = nil, *)
            if respond_to?(:as_json)
              as_json.to_json(state)
            else
              to_s.to_json(state)
            end
          end
        end
      end
    end
  end
end
