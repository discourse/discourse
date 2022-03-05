# frozen_string_literal: true

class GroupsController < ApplicationController
  requires_login only: [
    :set_notifications,
    :mentionable,
    :messageable,
    :check_name,
    :update,
    :histories,
    :request_membership,
    :search,
    :new,
    :test_email_settings
  ]

  skip_before_action :preload_json, :check_xhr, only: [:posts_feed, :mentions_feed]
  skip_before_action :check_xhr, only: [:show]
  after_action :add_noindex_header

  TYPE_FILTERS = {
    my: Proc.new { |groups, user|
      raise Discourse::NotFound unless user
      Group.member_of(groups, user)
    },
    owner: Proc.new { |groups, user|
      raise Discourse::NotFound unless user
      Group.owner_of(groups, user)
    },
    public: Proc.new { |groups|
      groups.where(public_admission: true, automatic: false)
    },
    close: Proc.new { |groups|
      groups.where(public_admission: false, automatic: false)
    },
    automatic: Proc.new { |groups|
      groups.where(automatic: true)
    },
    non_automatic: Proc.new { |groups|
      groups.where(automatic: false)
    }
  }
  ADD_MEMBERS_LIMIT = 1000

  def index
    unless SiteSetting.enable_group_directory? || current_user&.staff?
      raise Discourse::InvalidAccess.new(:enable_group_directory)
    end

    order = %w{name user_count}.delete(params[:order])
    dir = params[:asc].to_s == "true" ? "ASC" : "DESC"
    sort = order ? "#{order} #{dir}" : nil
    groups = Group.visible_groups(current_user, sort)
    type_filters = TYPE_FILTERS.keys

    if (username = params[:username]).present?
      raise Discourse::NotFound unless user = User.find_by_username(username)
      groups = TYPE_FILTERS[:my].call(groups.members_visible_groups(current_user, sort), user)
      type_filters = type_filters - [:my, :owner]
    end

    if (filter = params[:filter]).present?
      groups = Group.search_groups(filter, groups: groups)
    end

    if !guardian.is_staff?
      # hide automatic groups from all non stuff to de-clutter page
      groups = groups.where("automatic IS FALSE OR groups.id = #{Group::AUTO_GROUPS[:moderators]}")
      type_filters.delete(:automatic)
    end

    if Group.preloaded_custom_field_names.present?
      Group.preload_custom_fields(groups, Group.preloaded_custom_field_names)
    end

    if type = params[:type]&.to_sym
      raise Discourse::InvalidParameters.new(:type) unless callback = TYPE_FILTERS[type]
      groups = callback.call(groups, current_user)
    end

    if current_user
      group_users = GroupUser.where(group: groups, user: current_user)
      user_group_ids = group_users.pluck(:group_id)
      owner_group_ids = group_users.where(owner: true).pluck(:group_id)
    else
      type_filters = type_filters - [:my, :owner]
    end

    type_filters.delete(:non_automatic)

    # count the total before doing pagination
    total = groups.count

    page = params[:page].to_i
    page_size = MobileDetection.mobile_device?(request.user_agent) ? 15 : 36
    groups = groups.offset(page * page_size).limit(page_size)

    render_json_dump(
      groups: serialize_data(groups,
        BasicGroupSerializer,
        user_group_ids: user_group_ids || [],
        owner_group_ids: owner_group_ids || []
      ),
      extras: {
        type_filters: type_filters
      },
      total_rows_groups: total,
      load_more_groups: groups_path(
        page: page + 1,
        type: type,
        order: order,
        asc: params[:asc],
        filter: filter
      )
    )
  end

  def show
    respond_to do |format|
      group = find_group(:id)

      format.html do
        @title = group.full_name.present? ? group.full_name.capitalize : group.name
        @full_title = "#{@title} - #{SiteSetting.title}"
        @description_meta = group.bio_cooked.present? ? PrettyText.excerpt(group.bio_cooked, 300) : @title
        render :show
      end

      format.json do
        groups = Group.visible_groups(current_user)
        if !guardian.is_staff?
          groups = groups.where("automatic IS FALSE OR groups.id = #{Group::AUTO_GROUPS[:moderators]}")
        end

        render_json_dump(
          group: serialize_data(group, GroupShowSerializer, root: nil),
          extras: {
            visible_group_names: groups.pluck(:name)
          }
        )
      end
    end
  end

  def new
  end

  def edit
  end

  def update
    group = Group.find(params[:id])
    guardian.ensure_can_edit!(group) unless guardian.can_admin_group?(group)

    params_with_permitted = group_params(automatic: group.automatic)
    clear_disabled_email_settings(group, params_with_permitted)

    categories, tags = []
    if !group.automatic || current_user.admin
      notification_level, categories, tags = user_default_notifications(group, params_with_permitted)

      if params[:update_existing_users].blank?
        user_count = count_existing_users(group.group_users, notification_level, categories, tags)

        if user_count > 0
          render json: { user_count: user_count }
          return
        end
      end
    end

    if group.update(params_with_permitted)
      GroupActionLogger.new(current_user, group).log_change_group_settings
      group.record_email_setting_changes!(current_user)
      group.expire_imap_mailbox_cache
      update_existing_users(group.group_users, notification_level, categories, tags) if params[:update_existing_users] == "true"
      AdminDashboardData.clear_found_problem("group_#{group.id}_email_credentials")

      if guardian.can_see?(group)
        render json: success_json
      else
        # They can no longer see the group after changing permissions
        render json: { route_to: '/g' }
      end
    else
      render_json_error(group)
    end
  end

  def posts
    group = find_group(:group_id)
    guardian.ensure_can_see_group_members!(group)

    posts = group.posts_for(
      guardian,
      params.permit(:before_post_id, :category_id)
    ).limit(20)
    render_serialized posts.to_a, GroupPostSerializer
  end

  def posts_feed
    group = find_group(:group_id)
    guardian.ensure_can_see_group_members!(group)

    @posts = group.posts_for(
      guardian,
      params.permit(:before_post_id, :category_id)
    ).limit(50)
    @title = "#{SiteSetting.title} - #{I18n.t("rss_description.group_posts", group_name: group.name)}"
    @link = Discourse.base_url
    @description = I18n.t("rss_description.group_posts", group_name: group.name)
    render 'posts/latest', formats: [:rss]
  end

  def mentions
    raise Discourse::NotFound unless SiteSetting.enable_mentions?
    group = find_group(:group_id)
    posts = group.mentioned_posts_for(
      guardian,
      params.permit(:before_post_id, :category_id)
    ).limit(20)
    render_serialized posts.to_a, GroupPostSerializer
  end

  def mentions_feed
    raise Discourse::NotFound unless SiteSetting.enable_mentions?
    group = find_group(:group_id)
    @posts = group.mentioned_posts_for(
      guardian,
      params.permit(:before_post_id, :category_id)
    ).limit(50)
    @title = "#{SiteSetting.title} - #{I18n.t("rss_description.group_mentions", group_name: group.name)}"
    @link = Discourse.base_url
    @description = I18n.t("rss_description.group_mentions", group_name: group.name)
    render 'posts/latest', formats: [:rss]
  end

  def members
    group = find_group(:group_id)

    guardian.ensure_can_see_group_members!(group)

    limit = (params[:limit] || 50).to_i
    offset = params[:offset].to_i

    raise Discourse::InvalidParameters.new(:limit) if limit < 0 || limit > 1000
    raise Discourse::InvalidParameters.new(:offset) if offset < 0

    dir = (params[:asc] && params[:asc].present?) ? 'ASC' : 'DESC'
    if params[:desc]
      Discourse.deprecate(":desc is deprecated please use :asc instead", output_in_test: true, drop_from: '2.9.0')
      dir = (params[:desc] && params[:desc].present?) ? 'DESC' : 'ASC'
    end
    order = "NOT group_users.owner"

    if params[:requesters]
      guardian.ensure_can_edit!(group)

      users = group.requesters
      total = users.count

      if (filter = params[:filter]).present?
        filter = filter.split(',') if filter.include?(',')

        if current_user&.admin
          users = users.filter_by_username_or_email(filter)
        else
          users = users.filter_by_username(filter)
        end
      end

      users = users
        .select("users.*, group_requests.reason, group_requests.created_at requested_at")
        .order(params[:order] == 'requested_at' ? "group_requests.created_at #{dir}" : "")
        .order(username_lower: dir)
        .limit(limit)
        .offset(offset)

      return render json: {
        members: serialize_data(users, GroupRequesterSerializer),
        meta: {
          total: total,
          limit: limit,
          offset: offset
        }
      }
    end

    if params[:order] && %w{last_posted_at last_seen_at}.include?(params[:order])
      order = "#{params[:order]} #{dir} NULLS LAST"
    elsif params[:order] == 'added_at'
      order = "group_users.created_at #{dir}"
    end

    users = group.users.human_users
    total = users.count

    if (filter = params[:filter]).present?
      filter = filter.split(',') if filter.include?(',')

      if current_user&.admin
        users = users.filter_by_username_or_email(filter)
      else
        users = users.filter_by_username(filter)
      end
    end

    users = users
      .includes(:primary_group)
      .joins(:user_option)
      .select('users.*, user_options.timezone, group_users.created_at as added_at')
      .order(order)
      .order(username_lower: dir)

    members = users.limit(limit).offset(offset)
    owners = users.where('group_users.owner')

    render json: {
      members: serialize_data(members, GroupUserSerializer),
      owners: serialize_data(owners, GroupUserSerializer),
      meta: {
        total: total,
        limit: limit,
        offset: offset
      }
    }
  end

  def add_members
    group = Group.find(params[:id])
    guardian.ensure_can_edit!(group)

    users = users_from_params.to_a
    emails = []
    if params[:emails]
      params[:emails].split(",").each do |email|
        existing_user = User.find_by_email(email)
        existing_user.present? ? users.push(existing_user) : emails.push(email)
      end
    end

    guardian.ensure_can_invite_to_forum!([group]) if emails.present?

    if users.empty? && emails.empty?
      raise Discourse::InvalidParameters.new(I18n.t("groups.errors.usernames_or_emails_required"))
    end

    if users.length > ADD_MEMBERS_LIMIT
      return render_json_error(
        I18n.t("groups.errors.adding_too_many_users", count: ADD_MEMBERS_LIMIT)
      )
    end

    usernames_already_in_group = group.users.where(id: users.map(&:id)).pluck(:username)
    if usernames_already_in_group.present? &&
      usernames_already_in_group.length == users.length &&
      emails.blank?
      render_json_error(I18n.t(
        "groups.errors.member_already_exist",
        username: usernames_already_in_group.sort.join(", "),
        count: usernames_already_in_group.size
      ))
    else
      notify = params[:notify_users]&.to_s == "true"
      uniq_users = users.uniq
      uniq_users.each do |user|
        add_user_to_group(group, user, notify)
      end

      emails.each do |email|
        begin
          Invite.generate(current_user, email: email, group_ids: [group.id])
        rescue RateLimiter::LimitExceeded => e
          return render_json_error(I18n.t(
            "invite.rate_limit",
            count: SiteSetting.max_invites_per_day,
            time_left: e.time_left
          ))
        end
      end

      render json: success_json.merge!(
        usernames: uniq_users.map(&:username),
        emails: emails
      )
    end
  end

  def join
    ensure_logged_in
    unless current_user.staff?
      RateLimiter.new(current_user, "public_group_membership", 3, 1.minute).performed!
    end

    group = Group.find(params[:id])
    raise Discourse::NotFound unless group
    raise Discourse::InvalidAccess unless group.public_admission

    return if group.users.exists?(id: current_user.id)
    add_user_to_group(group, current_user)
  end

  def handle_membership_request
    group = Group.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) if group.blank?
    guardian.ensure_can_edit!(group)

    user = User.find_by(id: params[:user_id])
    raise Discourse::InvalidParameters.new(:user_id) if user.blank?

    ActiveRecord::Base.transaction do
      if params[:accept]
        group.add(user)
        GroupActionLogger.new(current_user, group).log_add_user_to_group(user)
      end

      GroupRequest.where(group_id: group.id, user_id: user.id).delete_all
    end

    if params[:accept]
      PostCreator.new(current_user,
        title: I18n.t('groups.request_accepted_pm.title', group_name: group.name),
        raw: I18n.t('groups.request_accepted_pm.body', group_name: group.name),
        archetype: Archetype.private_message,
        target_usernames: user.username,
        skip_validations: true
      ).create!
    end

    render json: success_json
  end

  def mentionable
    group = find_group(:group_id, ensure_can_see: false)

    if group
      render json: { mentionable: Group.mentionable(current_user).where(id: group.id).present? }
    else
      raise Discourse::InvalidAccess.new
    end
  end

  def messageable
    group = find_group(:group_id, ensure_can_see: false)

    if group
      render json: { messageable: guardian.can_send_private_message?(group) }
    else
      raise Discourse::InvalidAccess.new
    end
  end

  def check_name
    group_name = params.require(:group_name)
    checker = UsernameCheckerService.new(allow_reserved_username: true)
    render json: checker.check_username(group_name, nil)
  end

  def remove_member
    group = Group.find_by(id: params[:id])
    raise Discourse::NotFound unless group
    guardian.ensure_can_edit!(group)

    # Maintain backwards compatibility
    params[:usernames] = params[:username] if params[:username].present?
    params[:user_emails] = params[:user_email] if params[:user_email].present?

    users = users_from_params
    raise Discourse::InvalidParameters.new(
      'user_ids or usernames or user_emails must be present'
    ) if users.empty?

    removed_users = []
    skipped_users = []

    users.each do |user|
      if group.remove(user)
        removed_users << user.username
        GroupActionLogger.new(current_user, group).log_remove_user_from_group(user)
      else
        if group.users.exclude? user
          skipped_users << user.username
        else
          raise Discourse::InvalidParameters
        end
      end
    end

    render json: success_json.merge!(
      usernames: removed_users,
      skipped_usernames: skipped_users
    )
  end

  def leave
    ensure_logged_in
    unless current_user.staff?
      RateLimiter.new(current_user, "public_group_membership", 3, 1.minute).performed!
    end

    group = Group.find_by(id: params[:id])
    raise Discourse::NotFound unless group
    raise Discourse::InvalidAccess unless group.public_exit

    if group.remove(current_user)
      GroupActionLogger.new(current_user, group).log_remove_user_from_group(current_user)
    end
  end

  MAX_NOTIFIED_OWNERS ||= 20

  def request_membership
    params.require(:reason)

    group = find_group(:id)

    begin
      GroupRequest.create!(group: group, user: current_user, reason: params[:reason])
    rescue ActiveRecord::RecordNotUnique
      return render json: failed_json.merge(error: I18n.t("groups.errors.already_requested_membership")), status: 409
    end

    usernames = [current_user.username].concat(
      group.users.where('group_users.owner')
        .order("users.last_seen_at DESC")
        .limit(MAX_NOTIFIED_OWNERS)
        .pluck("users.username")
    )

    post = PostCreator.new(current_user,
      title: I18n.t('groups.request_membership_pm.title', group_name: group.name),
      raw: params[:reason],
      archetype: Archetype.private_message,
      target_usernames: usernames.join(','),
      topic_opts: { custom_fields: { requested_group_id: group.id } },
      skip_validations: true
    ).create!

    render json: success_json.merge(relative_url: post.topic.relative_url)
  end

  def set_notifications
    group = find_group(:id)
    notification_level = params.require(:notification_level)

    user_id = current_user.id
    if guardian.is_staff?
      user_id = params[:user_id] || user_id
    end

    GroupUser.where(group_id: group.id)
      .where(user_id: user_id)
      .update_all(notification_level: notification_level)

    render json: success_json
  end

  def histories
    group = find_group(:group_id)
    guardian.ensure_can_edit!(group) unless guardian.can_admin_group?(group)

    page_size = 25
    offset = (params[:offset] && params[:offset].to_i) || 0

    group_histories = GroupHistory.with_filters(group, params[:filters])
      .limit(page_size)
      .offset(offset * page_size)

    render_json_dump(
      logs: serialize_data(group_histories, BasicGroupHistorySerializer),
      all_loaded: group_histories.count < page_size
    )
  end

  def search
    groups = Group.visible_groups(current_user)
      .where("groups.id <> ?", Group::AUTO_GROUPS[:everyone])
      .includes(:flair_upload)
      .order(:name)

    if (term = params[:term]).present?
      groups = groups.where("name ILIKE :term OR full_name ILIKE :term", term: "%#{term}%")
    end

    if params[:ignore_automatic].to_s == "true"
      groups = groups.where(automatic: false)
    end

    if Group.preloaded_custom_field_names.present?
      Group.preload_custom_fields(groups, Group.preloaded_custom_field_names)
    end

    render_serialized(groups, BasicGroupSerializer)
  end

  def permissions
    group = find_group(:id)
    category_groups = group.category_groups.select { |category_group| guardian.can_see_category?(category_group.category) }
    render_serialized(category_groups.sort_by { |category_group| category_group.category.name }, CategoryGroupSerializer)
  end

  def test_email_settings
    params.require(:group_id)
    params.require(:protocol)
    params.require(:port)
    params.require(:host)
    params.require(:username)
    params.require(:password)
    params.require(:ssl)

    group = Group.find(params[:group_id])
    guardian.ensure_can_edit!(group)

    RateLimiter.new(current_user, "group_test_email_settings", 5, 1.minute).performed!

    settings = params.except(:group_id, :protocol)
    enable_tls = settings[:ssl] == "true"
    email_host = params[:host]

    if !["smtp", "imap"].include?(params[:protocol])
      raise Discourse::InvalidParameters.new("Valid protocols to test are smtp and imap")
    end

    hijack do
      begin
        case params[:protocol]
        when "smtp"
          enable_starttls_auto = false
          settings.delete(:ssl)

          final_settings = settings.merge(enable_tls: enable_tls, enable_starttls_auto: enable_starttls_auto)
            .permit(:host, :port, :username, :password, :enable_tls, :enable_starttls_auto, :debug)
          EmailSettingsValidator.validate_as_user(current_user, "smtp", **final_settings.to_h.symbolize_keys)
        when "imap"
          final_settings = settings.merge(ssl: enable_tls)
            .permit(:host, :port, :username, :password, :ssl, :debug)
          EmailSettingsValidator.validate_as_user(current_user, "imap", **final_settings.to_h.symbolize_keys)
        end
      rescue *EmailSettingsExceptionHandler::EXPECTED_EXCEPTIONS, StandardError => err
        return render_json_error(
          EmailSettingsExceptionHandler.friendly_exception_message(err, email_host)
        )
      end
      render json: success_json
    end
  end

  private

  def add_user_to_group(group, user, notify = false)
    group.add(user)
    GroupActionLogger.new(current_user, group).log_add_user_to_group(user)
    group.notify_added_to_group(user) if notify
  rescue ActiveRecord::RecordNotUnique
    # Under concurrency, we might attempt to insert two records quickly and hit a DB
    # constraint. In this case we can safely ignore the error and act as if the user
    # was added to the group.
  end

  def group_params(automatic: false)
    permitted_params =
      if automatic
        %i{
          visibility_level
          mentionable_level
          messageable_level
          default_notification_level
          bio_raw
          flair_icon
          flair_upload_id
          flair_bg_color
          flair_color
        }
      else
        default_params = %i{
          mentionable_level
          messageable_level
          title
          flair_icon
          flair_upload_id
          flair_bg_color
          flair_color
          bio_raw
          public_admission
          public_exit
          allow_membership_requests
          full_name
          default_notification_level
          membership_request_template
        }

        if current_user.staff?
          default_params.push(*[
            :incoming_email,
            :smtp_server,
            :smtp_port,
            :smtp_ssl,
            :smtp_enabled,
            :smtp_updated_by,
            :smtp_updated_at,
            :imap_server,
            :imap_port,
            :imap_ssl,
            :imap_mailbox_name,
            :imap_enabled,
            :imap_updated_by,
            :imap_updated_at,
            :email_username,
            :email_password,
            :email_from_alias,
            :primary_group,
            :visibility_level,
            :members_visibility_level,
            :name,
            :grant_trust_level,
            :automatic_membership_email_domains,
            :publish_read_state,
            :allow_unknown_sender_topic_replies
          ])

          custom_fields = DiscoursePluginRegistry.editable_group_custom_fields
          default_params << { custom_fields: custom_fields } unless custom_fields.blank?
        end

        default_params
      end

    if !automatic || current_user.admin
      [:muted, :regular, :tracking, :watching, :watching_first_post].each do |level|
        permitted_params << { "#{level}_category_ids" => [] }
        permitted_params << { "#{level}_tags" => [] }
      end
    end

    if guardian.can_associate_groups?
      permitted_params << { associated_group_ids: [] }
    end

    permitted_params = permitted_params | DiscoursePluginRegistry.group_params

    params.require(:group).permit(*permitted_params)
  end

  def find_group(param_name, ensure_can_see: true)
    name = params.require(param_name)
    group = Group.find_by("LOWER(name) = ?", name.downcase)
    raise Discourse::NotFound if ensure_can_see && !guardian.can_see_group?(group)
    group
  end

  def users_from_params
    if params[:usernames].present?
      users = User.where(username_lower: params[:usernames].split(",").map(&:downcase))
      raise Discourse::InvalidParameters.new(:usernames) if users.blank?
    elsif params[:user_id].present?
      users = User.where(id: params[:user_id].to_i)
      raise Discourse::InvalidParameters.new(:user_id) if users.blank?
    elsif params[:user_ids].present?
      users = User.where(id: params[:user_ids].to_s.split(","))
      raise Discourse::InvalidParameters.new(:user_ids) if users.blank?
    elsif params[:user_emails].present?
      users = User.with_email(params[:user_emails].split(","))
      raise Discourse::InvalidParameters.new(:user_emails) if users.blank?
    else
      users = []
    end
    users
  end

  def clear_disabled_email_settings(group, params_with_permitted)
    should_clear_imap = group.imap_enabled && params_with_permitted.key?(:imap_enabled) && params_with_permitted[:imap_enabled] == "false"
    should_clear_smtp = group.smtp_enabled && params_with_permitted.key?(:smtp_enabled) && params_with_permitted[:smtp_enabled] == "false"

    if should_clear_imap || should_clear_smtp
      params_with_permitted[:imap_server] = nil
      params_with_permitted[:imap_ssl] = false
      params_with_permitted[:imap_port] = nil
      params_with_permitted[:imap_mailbox_name] = ""
    end

    if should_clear_smtp
      params_with_permitted[:smtp_server] = nil
      params_with_permitted[:smtp_ssl] = false
      params_with_permitted[:smtp_port] = nil
      params_with_permitted[:email_username] = nil
      params_with_permitted[:email_password] = nil
    end
  end

  def user_default_notifications(group, params)
    category_notifications = group.group_category_notification_defaults.pluck(:category_id, :notification_level).to_h
    tag_notifications = group.group_tag_notification_defaults.pluck(:tag_id, :notification_level).to_h
    categories = {}
    tags = {}

    NotificationLevels.all.each do |key, value|
      category_ids = (params["#{key}_category_ids".to_sym] || []) - ["-1"]

      category_ids.each do |category_id|
        category_id = category_id.to_i
        old_value = category_notifications[category_id]

        metadata = {
          old_value: old_value,
          new_value: value
        }

        if old_value.blank?
          metadata[:action] = :create
        elsif old_value == value
          category_notifications.delete(category_id)
          next
        else
          metadata[:action] = :update
        end

        categories[category_id] = metadata
      end

      tag_names = (params["#{key}_tags".to_sym] || []) - ["-1"]
      tag_ids = Tag.where(name: tag_names).pluck(:id)

      tag_ids.each do |tag_id|
        old_value = tag_notifications[tag_id]

        metadata = {
          old_value: old_value,
          new_value: value
        }

        if old_value.blank?
          metadata[:action] = :create
        elsif old_value == value
          tag_notifications.delete(tag_id)
          next
        else
          metadata[:action] = :update
        end

        tags[tag_id] = metadata
      end
    end

    (category_notifications.keys - categories.keys).each do |category_id|
      categories[category_id] = { action: :delete, old_value: category_notifications[category_id] }
    end

    (tag_notifications.keys - tags.keys).each do |tag_id|
      tags[tag_id] = { action: :delete, old_value: tag_notifications[tag_id] }
    end

    notification_level = nil
    default_notification_level = params[:default_notification_level]&.to_i

    if default_notification_level.present? && group.default_notification_level != default_notification_level
      notification_level = {
        old_value: group.default_notification_level,
        new_value: default_notification_level
      }
    end

    [notification_level, categories, tags]
  end

  %i{
    count
    update
  }.each do |action|
    define_method("#{action}_existing_users") do |group_users, notification_level, categories, tags|
      return 0 if notification_level.blank? && categories.blank? && tags.blank?

      ids = []

      if notification_level.present?
        users = group_users.where(notification_level: notification_level[:old_value])

        if action == :update
          users.update_all(notification_level: notification_level[:new_value])
        else
          ids += users.pluck(:user_id)
        end
      end

      categories.each do |category_id, data|
        if data[:action] == :update || data[:action] == :delete
          category_users = CategoryUser.where(category_id: category_id, notification_level: data[:old_value], user_id: group_users.select(:user_id))

          if action == :update
            category_users.delete_all
          else
            ids += category_users.pluck(:user_id)
          end

          categories.delete(category_id) if data[:action] == :delete && action == :update
        end
      end

      tags.each do |tag_id, data|
        if data[:action] == :update || data[:action] == :delete
          tag_users = TagUser.where(tag_id: tag_id, notification_level: data[:old_value], user_id: group_users.select(:user_id))

          if action == :update
            tag_users.delete_all
          else
            ids += tag_users.pluck(:user_id)
          end

          tags.delete(tag_id) if data[:action] == :delete && action == :update
        end
      end

      if categories.present? || tags.present?
        group_users.select(:id, :user_id).find_in_batches do |batch|
          user_ids = batch.pluck(:user_id)

          categories.each do |category_id, data|
            category_users = []
            existing_users = CategoryUser.where(category_id: category_id, user_id: user_ids).where("notification_level IS NOT NULL")
            skip_user_ids = existing_users.pluck(:user_id)

            batch.each do |group_user|
              next if skip_user_ids.include?(group_user.user_id)
              category_users << { category_id: category_id, user_id: group_user.user_id, notification_level: data[:new_value] }
            end

            next if category_users.blank?

            if action == :update
              CategoryUser.insert_all!(category_users)
            else
              ids += category_users.pluck(:user_id)
            end
          end

          tags.each do |tag_id, data|
            tag_users = []
            existing_users = TagUser.where(tag_id: tag_id, user_id: user_ids).where("notification_level IS NOT NULL")
            skip_user_ids = existing_users.pluck(:user_id)

            batch.each do |group_user|
              next if skip_user_ids.include?(group_user.user_id)
              tag_users << { tag_id: tag_id, user_id: group_user.user_id, notification_level: data[:new_value], created_at: Time.now, updated_at: Time.now }
            end

            next if tag_users.blank?

            if action == :update
              TagUser.insert_all!(tag_users)
            else
              ids += tag_users.pluck(:user_id)
            end
          end
        end
      end

      ids.uniq.count
    end
  end
end
