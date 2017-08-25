require "administrate/field/belongs_to"

module Administrate
  class UserField < Administrate::Field::BelongsTo

    def to_s
      data
    end

  end
end
