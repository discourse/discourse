# frozen_string_literal: true

class Admin::SiteSettingsController < Admin::AdminController
  rescue_from Discourse::InvalidParameters do |e|
    render_json_error e.message, status: 422
  end

  def index
    params.permit(:categories, :plugin)

    render_json_dump(
      site_settings:
        SiteSetting.all_settings(
          filter_categories: params[:categories],
          filter_plugin: params[:plugin],
        ),
    )
  end

  def update
    params.require(:id)
    id = params[:id]
    update_existing_users = params[:update_existing_user].present?
    value = params[id]

    new_setting_name =
      SiteSettings::DeprecatedSettings::SETTINGS.find do |old_name, new_name, override, _|
        if old_name == id
          if !override
            raise Discourse::InvalidParameters,
                  "You cannot change this site setting because it is deprecated, use #{new_name} instead."
          end

          break new_name
        end
      end

    id = new_setting_name if new_setting_name

    previous_value = value_or_default(SiteSetting.get(id)) if update_existing_users

    SiteSetting::Update.call(params: { setting_name: id, new_value: value }, guardian:) do
      on_success do |params:|
        if update_existing_users
          SiteSettingUpdateExistingUsers.call(id, params.new_value, previous_value)
        end
        render body: nil
      end
      on_failed_policy(:setting_is_visible) do
        raise Discourse::InvalidParameters, I18n.t("errors.site_settings.site_setting_is_hidden")
      end
      on_failed_policy(:setting_is_configurable) do
        raise Discourse::InvalidParameters,
              I18n.t("errors.site_settings.site_setting_is_unconfigurable")
      end
    end
  end

  def user_count
    params.require(:site_setting_id)
    id = params[:site_setting_id]
    raise Discourse::NotFound unless id.start_with?("default_")
    new_value = value_or_default(params[id])

    raise_access_hidden_setting(id)
    previous_value = value_or_default(SiteSetting.public_send(id))
    json = {}

    if (user_option = SiteSettingUpdateExistingUsers.user_options[id.to_sym]).present?
      if user_option == "text_size_key"
        previous_value = UserOption.text_sizes[previous_value.to_sym]
      elsif user_option == "title_count_mode_key"
        previous_value = UserOption.title_count_modes[previous_value.to_sym]
      end

      json[:user_count] = UserOption.human_users.where(user_option => previous_value).count
    elsif id.start_with?("default_categories_")
      previous_category_ids = previous_value.split("|")
      new_category_ids = new_value.split("|")

      notification_level = SiteSettingUpdateExistingUsers.category_notification_level(id)

      user_ids =
        CategoryUser
          .where(
            category_id: previous_category_ids - new_category_ids,
            notification_level: notification_level,
          )
          .distinct
          .pluck(:user_id)
      user_ids +=
        User
          .real
          .joins("CROSS JOIN categories c")
          .joins("LEFT JOIN category_users cu ON users.id = cu.user_id AND c.id = cu.category_id")
          .where(staged: false)
          .where(
            "c.id IN (?) AND cu.notification_level IS NULL",
            new_category_ids - previous_category_ids,
          )
          .distinct
          .pluck("users.id")

      json[:user_count] = user_ids.uniq.count
    elsif id.start_with?("default_tags_")
      previous_tag_ids = Tag.where(name: previous_value.split("|")).pluck(:id)
      new_tag_ids = Tag.where(name: new_value.split("|")).pluck(:id)

      notification_level = SiteSettingUpdateExistingUsers.tag_notification_level(id)

      user_ids =
        TagUser
          .where(tag_id: previous_tag_ids - new_tag_ids, notification_level: notification_level)
          .distinct
          .pluck(:user_id)
      user_ids +=
        User
          .real
          .joins("CROSS JOIN tags t")
          .joins("LEFT JOIN tag_users tu ON users.id = tu.user_id AND t.id = tu.tag_id")
          .where(staged: false)
          .where("t.id IN (?) AND tu.notification_level IS NULL", new_tag_ids - previous_tag_ids)
          .distinct
          .pluck("users.id")

      json[:user_count] = user_ids.uniq.count
    elsif SiteSettingUpdateExistingUsers.is_sidebar_default_setting?(id)
      json[:user_count] = SidebarSiteSettingsBackfiller.new(
        id,
        previous_value: previous_value,
        new_value: new_value,
      ).number_of_users_to_backfill
    end

    render json: json
  end

  private

  def raise_access_hidden_setting(id)
    id = id.to_sym

    if SiteSetting.hidden_settings.include?(id)
      raise Discourse::InvalidParameters, "You are not allowed to change hidden settings"
    end

    if SiteSetting.plugins[id] && !Discourse.plugins_by_name[SiteSetting.plugins[id]].configurable?
      raise Discourse::InvalidParameters, "You are not allowed to change unconfigurable settings"
    end
  end

  def value_or_default(value)
    value.nil? ? "" : value
  end
end
