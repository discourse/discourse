# frozen_string_literal: true

# name: discourse-cakeday
# about: Show a birthday cake beside the user's name on their birthday and/or on the date they joined Discourse.
# version: 0.3
# authors: Alan Tan
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-cakeday

register_asset "stylesheets/cakeday.scss"
register_asset "stylesheets/emoji-images.scss"

register_svg_icon "cake-candles"

enabled_site_setting :cakeday_enabled

module ::DiscourseCakeday
  PLUGIN_NAME = "discourse-cakeday"
end

require_relative "lib/discourse_cakeday/engine"

after_initialize do
  DiscourseCakeday::Engine.routes.draw do
    get "birthdays" => "birthdays#index"
    get "birthdays/:filter" => "birthdays#index"
    get "anniversaries" => "anniversaries#index"
    get "anniversaries/:filter" => "anniversaries#index"
  end

  Discourse::Application.routes.append { mount DiscourseCakeday::Engine, at: "/cakeday" }

  require_relative "app/jobs/onceoff/fix_invalid_date_of_birth"
  require_relative "app/jobs/onceoff/migrate_date_of_birth_to_users_table"
  require_relative "app/serializers/discourse_cakeday/cakeday_user_serializer"
  require_relative "app/controllers/discourse_cakeday/cakeday_controller"
  require_relative "app/controllers/discourse_cakeday/anniversaries_controller"
  require_relative "app/controllers/discourse_cakeday/birthdays_controller"

  # overwrite the user and user_card serializers to show
  # the cakes on the user card and on the user profile pages
  %i[user user_card].each do |serializer|
    add_to_serializer(
      serializer,
      :cakedate,
      include_condition: -> { scope.user.present? && object.user_option&.hide_profile != true },
    ) do
      timezone = scope.user.user_option&.timezone.presence || "UTC"
      object.created_at.in_time_zone(timezone).strftime("%Y-%m-%d")
    end

    add_to_serializer(
      serializer,
      :birthdate,
      include_condition: -> do
        SiteSetting.cakeday_birthday_enabled && scope.user.present? &&
          object.user_option&.hide_profile != true
      end,
    ) { object.date_of_birth }
  end

  # overwrite the post serializer to show the cakes next to the
  # username in the posts stream
  add_to_serializer(
    :post,
    :user_cakedate,
    include_condition: -> do
      scope.user.present? && object.user&.created_at.present? &&
        object.user.user_option&.hide_profile != true
    end,
  ) do
    timezone = scope.user.user_option&.timezone.presence || "UTC"
    object.user.created_at.in_time_zone(timezone).strftime("%Y-%m-%d")
  end

  add_to_serializer(
    :post,
    :user_birthdate,
    include_condition: -> do
      SiteSetting.cakeday_birthday_enabled && scope.user.present? &&
        object.user&.date_of_birth.present? && object.user.user_option&.hide_profile != true
    end,
  ) { object.user.date_of_birth }
end
