class PluginStoreRow < ActiveRecord::Base
end

# == Schema Information
#
# Table name: plugin_store_rows
#
#  id          :integer          not null, primary key
#  plugin_name :string           not null
#  key         :string           not null
#  type_name   :string           not null
#  value       :text
#
# Indexes
#
#  index_plugin_store_rows_on_plugin_name_and_key  (plugin_name,key) UNIQUE
#
