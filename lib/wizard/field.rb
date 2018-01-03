class Wizard

  class Choice
    attr_reader :id, :label, :icon, :data, :extra_label
    attr_accessor :field

    def initialize(id, opts)
      @id = id
      @data = opts[:data]
      @label = opts[:label]
      @extra_label = opts[:extra_label]
      @icon = opts[:icon]
    end
  end

  class Field
    attr_reader :id, :type, :required, :value, :choices
    attr_accessor :step

    def initialize(attrs)
      attrs = attrs || {}

      @id = attrs[:id]
      @type = attrs[:type]
      @required = !!attrs[:required]
      @value = attrs[:value]
      @choices = []
    end

    def add_choice(id, opts = nil)
      choice = Choice.new(id, opts || {})
      choice.field = self

      @choices << choice
      choice
    end

  end
end
