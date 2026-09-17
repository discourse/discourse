# frozen_string_literal: true

module AdPlugin
  class DfpCategorySetting < ActiveRecord::Base
    self.table_name = "ad_plugin_dfp_category_settings"

    belongs_to :category
  end
end
