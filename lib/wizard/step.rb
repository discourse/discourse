class Wizard
  class Step
    attr_reader :id
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
  end
end
