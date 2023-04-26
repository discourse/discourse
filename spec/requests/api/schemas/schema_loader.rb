# frozen_string_literal: true

require "json"

module SpecSchemas
  class SpecLoader
    def initialize(filename)
      @filename = filename
    end

    def load
      JSON.parse(File.read(File.join(__dir__, "json", "#{@filename}.json")))
    end
  end
end
