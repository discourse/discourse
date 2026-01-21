# frozen_string_literal: true

# When JSON.dump or JSON.generate is called on certain Rails objects,
# the JSON gem passes a JSON::State object to to_json. The default implementations
# call `super`, which eventually reaches the JSON gem's native Object#to_json
# that doesn't respect Rails' as_json convention.
#
# When Oj was used, Oj::Rails.set_encoder() intercepted this and properly
# called as_json. This patch restores that behavior for specific classes when
# using the standard JSON gem.
#
# Note: We intentionally only patch specific classes (AMS serializers, Time, Date,
# DateTime, TimeWithZone) and not the JSON gem's Object#to_json because a broader patch breaks
# other JSON consumers like Playwright that communicate via JSON but don't expect
# Rails' as_json transformations.
#
# Without this patch:
# - JSON.dump(SomeSerializer.new(obj)) outputs "#<SomeSerializer:0x...>"
# - JSON.dump({time: Time.now}) outputs {"time":"2022-04-06 16:23:56 UTC"}
#   instead of {"time":"2022-04-06T16:23:56.000Z"}

module ActiveModel
  class Serializer
    def to_json(*args)
      if args.first.is_a?(::JSON::State)
        as_json.to_json(*args)
      elsif perform_caching?
        cache.fetch expand_cache_key([self.class.to_s.underscore, cache_key, "to-json"]) do
          super
        end
      else
        super
      end
    end
  end

  class ArraySerializer
    def to_json(*args)
      if args.first.is_a?(::JSON::State)
        as_json.to_json(*args)
      elsif perform_caching?
        cache.fetch expand_cache_key([self.class.to_s.underscore, cache_key, "to-json"]) do
          super
        end
      else
        super
      end
    end
  end
end

# Patch Time, Date, DateTime, TimeWithZone to use as_json when called from JSON.generate/dump
# This ensures ISO 8601 format is used instead of the JSON gem's default format
class Time
  def to_json(state = nil, *)
    if state.is_a?(::JSON::State)
      as_json.to_json(state)
    else
      super
    end
  end
end

module ActiveSupport
  class TimeWithZone
    def to_json(state = nil, *)
      if state.is_a?(::JSON::State)
        as_json.to_json(state)
      else
        super
      end
    end
  end
end

class Date
  def to_json(state = nil, *)
    if state.is_a?(::JSON::State)
      as_json.to_json(state)
    else
      super
    end
  end
end

class DateTime
  def to_json(state = nil, *)
    if state.is_a?(::JSON::State)
      as_json.to_json(state)
    else
      super
    end
  end
end
