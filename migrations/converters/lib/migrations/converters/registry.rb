# frozen_string_literal: true

module Migrations
  module Converters
    module Registry
      class << self
        def converters
          @converters ||= []
        end

        def register(converter_class)
          converters << converter_class unless converters.include?(converter_class)
        end

        def find(name)
          converters.find { |c| c.name.split("::").last.downcase == name.to_s.downcase }
        end

        def clear
          @converters = []
        end
      end
    end
  end
end
