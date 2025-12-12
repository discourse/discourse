# frozen_string_literal: true

# name: discourse-rewind
# about: A fun end-of-year summary for members' activity in the community.
# meta_topic_id: 390847
# version: 2025.12.0
# authors: Discourse
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-rewind
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

  def self.rewind_year(date = nil)
    date ||= Time.zone.now
    date.month == 1 ? date.year - 1 : date.year
  end

  def self.year_date_range(date_override = nil)
    current_date = date_override.presence || Time.zone.now

    # Outside December/January, only available in development
    is_rewind_period = current_date.month == 1 || current_date.month == 12
    return false if !is_rewind_period && !Rails.env.development?

    Date.new(current_date.year).all_year
  end
end

require_relative "lib/discourse_rewind/engine"

after_initialize do
  UserUpdater::OPTION_ATTR.push(:discourse_rewind_disabled, :discourse_rewind_share_publicly)

  %i[user_option current_user_option].each do |serializer|
    add_to_serializer(serializer, :discourse_rewind_disabled) { object.discourse_rewind_disabled }
    add_to_serializer(serializer, :discourse_rewind_dismissed) do
      dismissed_at = object.discourse_rewind_dismissed_at
      dismissed_at.present? &&
        DiscourseRewind.rewind_year(dismissed_at) >= DiscourseRewind.rewind_year
    end
  end

  add_to_serializer(:user_option, :discourse_rewind_share_publicly) do
    object.discourse_rewind_share_publicly
  end

  add_to_serializer(:current_user_option, :discourse_rewind_share_publicly) do
    object.discourse_rewind_share_publicly
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
