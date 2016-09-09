class Wizard
  class Step
    attr_reader :id, :updater
    attr_accessor :index, :fields, :next, :previous

    def initialize(id)
      @id = id
      @fields = []
    end

    def add_field(attrs)
      field = Field.new(attrs)
      field.step = self
      @fields << field
      field
    end

    def on_update(&block)
      @updater = block
    end
  end
end
