# frozen_string_literal: true

module DiscourseCakeday
  class AnniversariesController < CakedayController
    before_action :ensure_cakeday_enabled

    def index
      column_sql = "created_at"

      # The users.created_at column is a "timestamp without timezone"
      # so we need to convert the "point in time" to the current user's timezone
      # for proper filtering and display (otherwise you might get off by ones
      # if you live in ~~the future~~ Fiji or in ~~the past~~ Hawaii)
      if @timezone.present? && @timezone != "UTC"
        column_sql += " AT TIME ZONE 'UTC' AT TIME ZONE '#{@timezone}'"
      end

      users, total, more_params = cakedays_by(column_sql, at_least_one_year_old: true)

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
