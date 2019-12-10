# frozen_string_literal: true

class ResolveDuplicateGroupNames < ActiveRecord::Migration[4.2]

  def up
    results = DB.query_single 'SELECT id FROM groups
                              WHERE name ILIKE
                               (SELECT lower(name)
                                FROM groups
                                GROUP BY lower(name)
                                HAVING count(*) > 1);'

    groups = Group.where id: results
    groups.group_by { |g| g.name.downcase }.each do |key, value|
      value.each_with_index do |dup, index|
        dup.update! name: "#{dup.name[0..18]}_#{index + 1}" if index > 0
      end
    end
  end

  def down
    # does not reverse changes
  end

end
