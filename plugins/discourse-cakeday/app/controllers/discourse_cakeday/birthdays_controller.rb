# frozen_string_literal: true

module DiscourseCakeday
  class BirthdaysController < CakedayController
    before_action :ensure_birthday_enabled

    def index
      users, total, more_params = cakedays_by("date_of_birth")

      render_json_dump(
        birthdays: serialize_data(users, CakedayUserSerializer),
        total_rows_birthdays: total,
        load_more_birthdays: birthdays_path(more_params),
      )
    end

    private

    def ensure_birthday_enabled
      raise Discourse::NotFound if !SiteSetting.cakeday_birthday_enabled
    end
  end
end
