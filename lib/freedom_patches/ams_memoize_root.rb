# frozen_string_literal: true

module ActiveModel
  class ArraySerializer
    extend ActiveSupport::DescendantsTracker
    def to_json(*args)
      if perform_caching?
        cache.fetch expand_cache_key([self.class.to_s.underscore, cache_key, 'to-json']) do
          ActiveSupport::JSON.encode(as_json)
        end
      else
        ActiveSupport::JSON.encode(as_json)
      end
    end
  end

  class Serializer
    class << self
      attr_accessor :root_from_class_name
    end

    def root_name
      return false if self._root == false

      if !self.class.root_from_class_name
        self.class.root_from_class_name = self.class.name.present? && self.class.name.demodulize.underscore.sub(/_serializer$/, '').to_sym
      end

      if self._root == true
        self.class.root_from_class_name
      else
        self._root || self.class.root_from_class_name
      end
    end

    def to_json(*args)
      if perform_caching?
        cache.fetch expand_cache_key([self.class.to_s.underscore, cache_key, 'to-json']) do
          ActiveSupport::JSON.encode(as_json)
        end
      else
        ActiveSupport::JSON.encode(as_json)
      end
    end
  end
end
