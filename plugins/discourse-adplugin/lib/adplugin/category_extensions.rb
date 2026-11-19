# frozen_string_literal: true

module AdPlugin
  module CategoryExtensions
    extend ActiveSupport::Concern

    prepended do
      has_one :ad_plugin_dfp_category_setting,
              class_name: "AdPlugin::DfpCategorySetting",
              dependent: :destroy
    end
  end
end
