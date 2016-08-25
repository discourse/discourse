class Wizard
  class Field
    attr_reader :id, :type, :required, :value
    attr_accessor :step

    def initialize(attrs)
      attrs = attrs || {}

      @id = attrs[:id]
      @type = attrs[:type]
      @required = !!attrs[:required]
      @value = attrs[:value]
    end
  end
end
