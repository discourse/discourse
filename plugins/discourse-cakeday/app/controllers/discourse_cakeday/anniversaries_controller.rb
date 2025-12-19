# frozen_string_literal: true

module DiscourseCakeday
  class AnniversariesController < CakedayController
    before_action :ensure_cakeday_enabled

    def index
      users, total, more_params =
        cakedays_by("created_at", at_least_one_year_old: true, apply_timezone: true)

      render_json_dump(
        anniversaries: serialize_data(users, CakedayUserSerializer),
        total_rows_anniversaries: total,
        load_more_anniversaries: anniversaries_path(more_params),
      )
    end

    private

    def ensure_cakeday_enabled
      raise Discourse::NotFound if !SiteSetting.cakeday_enabled
    end
  end
end
