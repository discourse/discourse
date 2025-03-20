# frozen_string_literal: true

module Migrations::Importer
  StepStats = Struct.new(:progress, :skip_count, :warning_count, :error_count)
end
