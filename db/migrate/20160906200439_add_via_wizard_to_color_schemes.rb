class AddViaWizardToColorSchemes < ActiveRecord::Migration
  def change
    add_column :color_schemes, :via_wizard, :boolean, default: false, null: false
  end
end
