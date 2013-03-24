class RemoveSiteId < ActiveRecord::Migration
  def up
    drop_table 'sites'
    remove_index 'incoming_links', name: "incoming_index"
    add_index "incoming_links", ["forum_thread_id", "post_number"], name: "incoming_index"
    remove_column 'incoming_links', 'site_id'
    remove_index 'users', name: 'index_users_on_site_id'
    remove_column 'users', 'site_id'

    remove_index 'expression_types', name: 'index_expression_types_on_site_id_and_expression_index'
    remove_index 'expression_types', name: 'index_expression_types_on_site_id_and_name'
    remove_column 'expression_types','site_id'
    add_index "expression_types", ["expression_index"], unique: true
    add_index "expression_types", ["name"], unique: true

    drop_table 'forums'
  end

  def down
    raise 'not reversable'
  end
end
