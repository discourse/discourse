# frozen_string_literal: true

module AdPlugin
  class DfpCategorySettingSerializer < ApplicationSerializer
    attributes :id, :category_id, :gam_adunit, :gam_keywords, :gtm_taxonomy
  end
end
