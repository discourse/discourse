# frozen_string_literal: true

module Jobs
  class ClearWidthAndHeight < ::Jobs::Onceoff
    def execute_onceoff(args)
      # we have to clear all old uploads cause
      # we could have old versions of height / width
      # this column used to store thumbnail size instead of
      # actual size
      DB.exec(<<~SQL)
        UPDATE uploads
        SET width = null, height = null
        WHERE width IS NOT NULL OR height IS NOT NULL
      SQL
    end
  end
end
