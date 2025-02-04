# frozen_string_literal: true

module Migrations::Converters::Example
  class Converter < ::Migrations::Converters::Base::Converter
    def steps
      [Step1, Step2, Step3, Step4]
    end
  end
end
