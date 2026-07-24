module Holidays
  module Definition
    module Entity
      Test = Struct.new(:dates, :regions, :options, :name, :holiday?) do
        def initialize(fields = {})
          super(*fields.values_at(*members))
        end
      end
    end
  end
end
