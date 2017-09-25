class AddViaWizardToColorSchemes < ActiveRecord::Migration[4.2]
  def change
    add_column :color_schemes, :via_wizard, :boolean, default: false, null: false
    add_column :color_schemes, :theme_id, :string, null: true
  end
end
