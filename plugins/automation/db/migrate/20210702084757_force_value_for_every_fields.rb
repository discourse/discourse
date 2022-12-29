# frozen_string_literal: true

class ForceValueForEveryFields < ActiveRecord::Migration[6.1]
  def up
    mapping = {
      "group" => "group_id",
      "user" => "username",
      "pms" => "pms",
      "text" => "text",
      "text_list" => "list",
      "category" => "category_id",
      "tags" => "tags",
    }
    DiscourseAutomation::Field
      .where(component: mapping.keys)
      .find_each do |field|
        if mapping[field.component].present?
          metadata = field.metadata
          metadata["value"] = metadata.delete(mapping[field.component])
          field.update_column(:metadata, metadata)
        end
      end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
