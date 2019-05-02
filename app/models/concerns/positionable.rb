# frozen_string_literal: true

module Positionable
  extend ActiveSupport::Concern

  included do
    before_save do
      self.position ||= self.class.count
    end
  end

  def move_to(position_arg)

    position = [[position_arg, 0].max, self.class.count - 1].min

    if self.position.nil? || position > (self.position)
      DB.exec "
      UPDATE #{self.class.table_name}
      SET position = position - 1
      WHERE position > :current_position and position <= :new_position",
      current_position: self.position, new_position: position
    elsif position < self.position
      DB.exec "
      UPDATE #{self.class.table_name}
      SET position = position + 1
      WHERE position >= :new_position and position < :current_position",
      current_position: self.position, new_position: position
    else
      # Not moving to a new position
      return
    end

    DB.exec "
    UPDATE #{self.class.table_name}
    SET position = :position
    WHERE id = :id", id: id, position: position
  end
end
