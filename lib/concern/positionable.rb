module Concern
  module Positionable
    extend ActiveSupport::Concern

    included do
      before_save do
        self.position ||= self.class.count
      end
    end

    def move_to(position)

      self.exec_sql "
      UPDATE #{self.class.table_name}
      SET position = position - 1
      WHERE position > :position AND position > 0", {position: self.position}

      self.exec_sql "
      UPDATE #{self.class.table_name}
      SET position = :position
      WHERE id = :id", {id: id, position: position}

      self.exec_sql "
      UPDATE #{self.class.table_name} t
      SET position = x.position - 1
      FROM (
        SELECT i.id, row_number()
          OVER(ORDER BY i.position asc,
                        CASE WHEN i.id = :id THEN 0 ELSE 1 END ASC) AS position
        FROM #{self.class.table_name} i
        WHERE i.position IS NOT NULL
      ) x
      WHERE x.id = t.id AND t.position <> x.position - 1
      ", {id: id}
    end
  end
end
