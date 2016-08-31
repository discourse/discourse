class Wizard
  class Field

    attr_reader :id, :type, :required, :value, :options
    attr_accessor :step

    def initialize(attrs)
      attrs = attrs || {}

      @id = attrs[:id]
      @type = attrs[:type]
      @required = !!attrs[:required]
      @value = attrs[:value]
      @options = []
    end

    def add_option(id)
      @options << id
    end

  end
end
