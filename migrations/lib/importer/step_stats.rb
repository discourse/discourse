# frozen_string_literal: true

module Migrations::Importer
  StepStats =
    Struct.new(:skip_count, :warning_count, :error_count) do
      def reset(skip_count: 0, warning_count: 0, error_count: 0)
        self.skip_count = skip_count
        self.warning_count = warning_count
        self.error_count = error_count
      end
    end
end
