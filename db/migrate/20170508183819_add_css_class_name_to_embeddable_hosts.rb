class AddCssClassNameToEmbeddableHosts < ActiveRecord::Migration[4.2]
  def change
    add_column :embeddable_hosts, :class_name, :string
  end
end
