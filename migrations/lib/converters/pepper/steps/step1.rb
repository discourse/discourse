# frozen_string_literal: true

module Migrations::Converters::Pepper
  class Step1 < Migrations::Converters::BaseStep
    title "Hello world"
    run_in_parallel true
  end
end
