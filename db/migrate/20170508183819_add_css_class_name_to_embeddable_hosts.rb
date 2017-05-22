class AddCssClassNameToEmbeddableHosts < ActiveRecord::Migration
  def change
    add_column :embeddable_hosts, :class_name, :string
  end
end
