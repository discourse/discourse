# frozen_string_literal: true

module Migrations::Converters::Pepper
  class Converter < Migrations::Converters::BaseConverter
    def steps
      [Step1, Step2, Step3]
    end
  end
end
