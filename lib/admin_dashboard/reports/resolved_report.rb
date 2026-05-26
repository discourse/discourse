# frozen_string_literal: true

module AdminDashboard
  module Reports
    ResolvedReport =
      Data.define(:source, :identifier, :title, :description, :label, :url) do
        def key
          "#{source}:#{identifier}"
        end

        def to_h
          super.merge(key: key)
        end
      end
  end
end
