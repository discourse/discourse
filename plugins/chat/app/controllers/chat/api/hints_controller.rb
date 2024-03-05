# frozen_string_literal: true

class Chat::Api::HintsController < ApplicationController
  requires_plugin Chat::PLUGIN_NAME

  before_action :ensure_logged_in

  def check_group_mentions
    RateLimiter.new(current_user, "group_mention_hints", 5, 10.seconds).performed!
    group_names = params[:mentions]

    raise Discourse::InvalidParameters.new(:mentions) if group_names.blank?

    visible_groups =
      Group.where("LOWER(name) IN (?)", group_names).visible_groups(current_user).pluck(:name)

    mentionable_groups = filter_mentionable_groups(visible_groups)

    result = {
      unreachable: visible_groups - mentionable_groups.map(&:name),
      over_members_limit:
        mentionable_groups
          .select { |g| g.user_count > SiteSetting.max_users_notified_per_group_mention }
          .map(&:name),
    }

    result[:invalid] = (group_names - result[:unreachable]) - result[:over_members_limit]

    render json: result
  end

  private

  def filter_mentionable_groups(group_names)
    return [] if group_names.empty?

    Group
      .select(:name, :user_count)
      .where(name: group_names)
      .mentionable(current_user, include_public: false)
  end
end
