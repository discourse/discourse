# frozen_string_literal: true

module Migrations::SetStore
  module Interface
    def add(...)
      raise NotImplementedError
    end

    def add?(...)
      raise NotImplementedError
    end

    def include?(...)
      raise NotImplementedError
    end

    def bulk_add(records)
      raise NotImplementedError
    end
  end
end
