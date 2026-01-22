# frozen_string_literal: true

# When JSON.dump or JSON.generate is called on objects, the JSON gem passes a
# JSON::State object to to_json. ActiveSupport's ToJsonWithActiveSupportEncoder
# detects this and forwards to the native JSON gem's Object#to_json, which just
# converts objects to strings using #to_s instead of respecting #as_json.
#
# When Oj was used, Oj::Rails.set_encoder() intercepted this and properly
# called as_json. This patch restores that behavior for the standard JSON gem.
#
# We only call as_json for objects that have a CUSTOM as_json implementation
# (not the default Object#as_json). This avoids breaking JSON consumers like
# Playwright that send plain objects over JSON and don't expect Rails' default
# as_json transformations (which converts objects to their instance_values).
#
# Without this patch:
# - JSON.dump(SomeSerializer.new(obj)) outputs "#<SomeSerializer:0x...>"
# - JSON.dump(Report.new(:test)) outputs "#<Report:0x...>"
# - JSON.dump({time: Time.now}) outputs {"time":"2022-04-06 16:23:56 UTC"}
#   instead of {"time":"2022-04-06T16:23:56.000Z"}

module JSON
  module Ext
    module Generator
      module GeneratorMethods
        module Object
          def to_json(state = nil, *)
            # Only use as_json if the object has a custom implementation
            # (not the default Object#as_json which does unexpected transformations)
            if method(:as_json).owner != ::Object
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
