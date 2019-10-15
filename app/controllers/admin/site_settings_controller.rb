# frozen_string_literal: true

class Admin::SiteSettingsController < Admin::AdminController
  rescue_from Discourse::InvalidParameters do |e|
    render_json_error e.message, status: 422
  end

  def index
    render_json_dump(site_settings: SiteSetting.all_settings, diags: SiteSetting.diags)
  end

  def update
    params.require(:id)
    id = params[:id]
    value = params[id]
    value.strip! if value.is_a?(String)
    raise_access_hidden_setting(id)

    if SiteSetting.type_supervisor.get_type(id) == :upload
      value = Upload.find_by(url: value) || ''
    end

    update_existing_users = params[:updateExistingUsers].present?
    previous_category_ids = (SiteSetting.send(id) || "").split("|") if update_existing_users

    SiteSetting.set_and_log(id, value, current_user)

    if update_existing_users
      new_category_ids = (value || "").split("|")

      case id
      when "default_categories_watching"
        notification_level = NotificationLevels.all[:watching]
      when "default_categories_tracking"
        notification_level = NotificationLevels.all[:tracking]
      when "default_categories_muted"
        notification_level = NotificationLevels.all[:muted]
      when "default_categories_watching_first_post"
        notification_level = NotificationLevels.all[:watching_first_post]
      end

      (previous_category_ids - new_category_ids).each do |category_id|
        CategoryUser.where(category_id: category_id, notification_level: notification_level).delete_all
      end

      (new_category_ids - previous_category_ids).each do |category_id|
        skip_user_ids = CategoryUser.where(category_id: category_id).pluck(:user_id)

        User.where.not(id: skip_user_ids).select(:id).find_in_batches do |users|
          category_users = []
          users.each { |user| category_users << { category_id: category_id, user_id: user.id, notification_level: notification_level } }
          CategoryUser.insert_all!(category_users)
        end

        CategoryUser.where(category_id: category_id, notification_level: notification_level).first_or_create!(notification_level: notification_level)
      end
    end

    render body: nil
  end

  private

  def raise_access_hidden_setting(id)
    # note, as of Ruby 2.3 symbols are GC'd so this is considered safe
    if SiteSetting.hidden_settings.include?(id.to_sym)
      raise Discourse::InvalidParameters, "You are not allowed to change hidden settings"
    end
  end

end
