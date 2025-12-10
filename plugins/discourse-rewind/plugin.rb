# frozen_string_literal: true

# name: discourse-rewind
# about: A fun end-of-year summary for members' activity in the community.
# meta_topic_id: https://meta.discourse.org/t/discourse-rewind-2024/348063
# version: 2025.12.0
# authors: Discourse
# url: https://github.com/discourse/discourse-rewind
# required_version: 2.7.0

enabled_site_setting :discourse_rewind_enabled

register_svg_icon "repeat"
register_svg_icon "volume-high"
register_svg_icon "volume-xmark"

register_asset "stylesheets/common/_index.scss"
register_asset "stylesheets/mobile/_index.scss", :mobile

module ::DiscourseRewind
  PLUGIN_NAME = "discourse-rewind"

  def self.public_asset_path(name)
    File.expand_path(File.join(__dir__, "public", name))
  end

  def self.year_date_range(date_override = nil)
    if date_override.present?
      current_date = date_override
    else
      current_date = Time.zone.now
    end

    current_month = current_date.month
    current_year = current_date.year

    case current_month
    when 1
      current_year - 1
    when 12
      current_year
    else
      # Otherwise it's impossible to test in browser locally unless you're
      # in December or January
      if Rails.env.development?
        current_year
      else
        false
      end
    end

    Date.new(current_year).all_year
  end
end

require_relative "lib/discourse_rewind/engine"

after_initialize do
  UserUpdater::OPTION_ATTR.push(:discourse_rewind_disabled)

  add_to_serializer(:user_option, :discourse_rewind_disabled) { object.discourse_rewind_disabled }

  add_to_serializer(:current_user_option, :discourse_rewind_disabled) do
    object.discourse_rewind_disabled
  end

  add_to_serializer(:current_user, :is_rewind_active) do
    Rails.env.development? || Date.today.month == 1 || Date.today.month == 12
  end

  Discourse::Application.routes.append do
    get "u/:username/preferences/rewind" => "users#preferences",
        :constraints => {
          username: RouteFormat.username,
        }
  end
end
