class Wizard
  class Field

    attr_reader :id, :type, :required, :value, :options, :option_data
    attr_accessor :step

    def initialize(attrs)
      attrs = attrs || {}

      @id = attrs[:id]
      @type = attrs[:type]
      @required = !!attrs[:required]
      @value = attrs[:value]
      @options = []
      @option_data = {}
    end

    def add_option(id, data=nil)
      @options << id
      @option_data[id] = data
    end

  end
end
