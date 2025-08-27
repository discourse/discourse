# frozen_string_literal: true

module Jobs
  class SiteSettingUpdateDefaultCategories < ::Jobs::Base
    # There should only be one of these jobs running at a time
    cluster_concurrency 1

    def execute(args)
      id = args[:id]
      value = args[:value]
      previous_value = args[:previous_value]

      SiteSettingUpdateExistingUsers.default_categories(id, value, previous_value)
    end
  end
end
