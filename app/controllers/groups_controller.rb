# frozen_string_literal: true

class GroupsController < ApplicationController
  requires_login only: %i[
                   set_notifications
                   mentionable
                   messageable
                   check_name
                   update
                   histories
                   request_membership
                   search
                   new
                   test_email_settings
                   add_members
                   add_owners
                   remove_member
                   handle_membership_request
                   edit
                 ]

  skip_before_action :preload_json, :check_xhr, only: %i[posts_feed mentions_feed]
  skip_before_action :check_xhr, only: [:show]
  after_action :add_noindex_header

  TYPE_FILTERS = GroupDirectoryQuery::TYPE_FILTERS

  def index
    page = fetch_int_from_params(:page, default: 0)
    page_size = MobileDetection.mobile_device?(request.user_agent) ? 15 : 36
    filter = params[:filter]
    type = params[:type]
    result =
      GroupDirectoryQuery.new(user: current_user, guardian:, modifier_context: self).call(
        username: params[:username],
        filter:,
        type:,
        order: params[:order],
        ascending: params[:asc].to_s == "true",
        page:,
        limit: page_size,
      )
    user_group_ids = result.memberships.keys
    owner_group_ids =
      result.memberships.filter_map { |group_id, membership| group_id if membership.owner? }

    render_json_dump(
      groups:
        serialize_data(result.groups, BasicGroupSerializer, user_group_ids:, owner_group_ids:),
      extras: {
        type_filters: result.type_filters,
      },
      total_rows_groups: result.total,
      load_more_groups:
        groups_path(
          page: page + 1,
          type: type,
          order: result.order,
          asc: result.order ? params[:asc] : nil,
          filter: filter,
        ),
    )
  end

  def show
    respond_to do |format|
      group = find_group_for_show

      format.html do
        @title = group.full_name.present? ? group.full_name.capitalize : group.name
        @full_title = "#{@title} - #{SiteSetting.title}"
        @description_meta = group.bio_summary || @title
        render :show
      end

      format.json do
        groups = Group.visible_groups(current_user)
        if !guardian.is_staff?
          groups =
            groups.where(
              "groups.automatic IS FALSE OR groups.id = ?",
              Group::AUTO_GROUPS[:moderators],
            )
        end

        render_json_dump(
          group: serialize_data(group, GroupShowSerializer, root: nil),
          extras: {
            visible_group_names: groups.pluck(:name),
          },
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
    guardian.ensure_can_edit!(group) if !guardian.can_admin_group?(group)

    attributes = params.require(:group).permit(*GroupUpdater.permitted_params(guardian, group:))
    updated =
      GroupUpdater.update(guardian, group, attributes, update_existing_users: existing_users_choice)
    return render_json_error(group) if !updated

    # Redirect user to groups index page if they can no longer see the group
    return redirect_with_client_support groups_path if !guardian.can_see?(group)

    render json: success_json
  rescue GroupUpdater::ExistingUsersConfirmationRequired => error
    render status: :unprocessable_entity,
           json: {
             user_count: error.user_count,
             errors: [error.message],
           }
  end

  def posts
    group = find_group(:name)
    guardian.ensure_can_see_group_members!(group)

    posts =
      group.posts_for(guardian, params.permit(:before_post_id, :before, :category_id)).limit(20)

    response = { posts: serialize_data(posts, GroupPostSerializer) }

    if guardian.can_lazy_load_categories?
      category_ids = posts.map { |p| p.topic.category_id }.compact.uniq
      categories = Category.secured(guardian).with_parents(category_ids)
      response[:categories] = serialize_data(categories, CategoryBadgeSerializer)
    end

    render json: response
  end

  def posts_feed
    group = find_group(:name)
    guardian.ensure_can_see_group_members!(group)

    @posts =
      group.posts_for(guardian, params.permit(:before_post_id, :before, :category_id)).limit(50)
    @title =
      "#{SiteSetting.title} - #{I18n.t("rss_description.group_posts", group_name: group.name)}"
    @link = Discourse.base_url
    @description = I18n.t("rss_description.group_posts", group_name: group.name)

    render "posts/latest", formats: [:rss]
  end

  def mentions
    raise Discourse::NotFound unless SiteSetting.enable_mentions?

    group = find_group(:name)
    guardian.ensure_can_see_group_members!(group)

    posts =
      group.mentioned_posts_for(
        guardian,
        params.permit(:before_post_id, :before, :category_id),
      ).limit(20)

    response = { posts: serialize_data(posts, GroupPostSerializer) }

    if guardian.can_lazy_load_categories?
      category_ids = posts.map { |p| p.topic.category_id }.compact.uniq
      categories = Category.secured(guardian).with_parents(category_ids)
      response[:categories] = serialize_data(categories, CategoryBadgeSerializer)
    end

    render json: response
  end

  def mentions_feed
    raise Discourse::NotFound unless SiteSetting.enable_mentions?

    group = find_group(:name)
    guardian.ensure_can_see_group_members!(group)

    @posts =
      group.mentioned_posts_for(
        guardian,
        params.permit(:before_post_id, :before, :category_id),
      ).limit(50)
    @title =
      "#{SiteSetting.title} - #{I18n.t("rss_description.group_mentions", group_name: group.name)}"
    @link = Discourse.base_url
    @description = I18n.t("rss_description.group_mentions", group_name: group.name)

    render "posts/latest", formats: [:rss]
  end

  MEMBERS_MAX_PAGE_SIZE = 1_000
  MEMBERS_DEFAULT_PAGE_SIZE = 50

  def members
    group = find_group(:name)

    guardian.ensure_can_see_group_members!(group)

    limit = fetch_limit_from_params(default: MEMBERS_DEFAULT_PAGE_SIZE, max: MEMBERS_MAX_PAGE_SIZE)
    offset = params[:offset].to_i

    raise Discourse::InvalidParameters.new(:offset) if offset < 0

    dir = params[:asc].to_s == "true" ? "ASC" : "DESC"
    order = "NOT group_users.owner"

    if params[:requesters]
      guardian.ensure_can_edit!(group)

      users = group.requesters
      total = users.count

      if (filter = params[:filter]).present?
        filter = filter.split(",") if filter.include?(",")

        if current_user&.admin
          users = users.filter_by_username_or_email(filter)
        else
          users = users.filter_by_username(filter)
        end
      end

      users =
        users
          .select("users.*, group_requests.reason, group_requests.created_at requested_at")
          .order(params[:order] == "requested_at" ? "group_requests.created_at #{dir}" : "")
          .order(username_lower: dir)
          .limit(limit)
          .offset(offset)

      return(
        render json: {
                 members: serialize_data(users, GroupRequesterSerializer),
                 meta: {
                   total: total,
                   limit: limit,
                   offset: offset,
                 },
               }
      )
    end

    include_custom_fields = params[:include_custom_fields] == "true"

    allowed_fields = User.allowed_user_custom_fields(guardian)
    if guardian.is_staff?
      allowed_fields += UserField.all.pluck(:id).map { |fid| "#{User::USER_FIELD_PREFIX}#{fid}" }
    end

    if params[:order] && %w[last_posted_at last_seen_at].include?(params[:order])
      order = "#{params[:order]} #{dir} NULLS LAST"
    elsif params[:order] == "added_at"
      order = "group_users.created_at #{dir}"
    elsif include_custom_fields && params[:order] == "custom_field" &&
          allowed_fields.include?(params[:order_field])
      order =
        "(SELECT value FROM user_custom_fields ucf WHERE ucf.user_id = users.id AND ucf.name = #{ActiveRecord::Base.connection.quote(params[:order_field])}) #{dir} NULLS LAST"
    end

    users = group.listed_users
    total = users.count

    if (filter = params[:filter]).present?
      filter = filter.split(",") if filter.include?(",")

      if current_user&.admin
        users = users.filter_by_username_or_email(filter)
      else
        users = users.filter_by_username(filter)
      end
    end

    users =
      users
        .includes(:primary_group)
        .includes(:user_option)
        .select("users.*, group_users.created_at as added_at")
        .order(order)
        .order(username_lower: dir)

    members = users.limit(limit).offset(offset)
    owners = users.where("group_users.owner")

    render json: {
             members: serialize_data(members, GroupUserWithCustomFieldsSerializer),
             owners: serialize_data(owners, GroupUserWithCustomFieldsSerializer),
             meta: {
               total: total,
               limit: limit,
               offset: offset,
             },
           }
  end

  def add_members
    group = Group.find(params[:id])

    result =
      GroupMemberAdder.add(
        guardian,
        group,
        **user_selectors,
        emails: params[:emails],
        notify_users: notify_users_choice,
        skip_email: params[:skip_email].to_s == "true",
      )

    render json: success_json.merge!(usernames: result[:usernames], emails: result[:emails])
  rescue GroupMemberAdder::EmailsNotAllowed,
         GroupMemberAdder::TooManyUsers,
         GroupMemberAdder::AlreadyMembers => error
    render_json_error(error.message)
  rescue RateLimiter::LimitExceeded => error
    render_json_error(
      I18n.t(
        "invite.rate_limit",
        count: SiteSetting.max_invites_per_day,
        time_left: error.time_left,
      ),
    )
  end

  def add_owners
    group = Group.find_by(id: params.require(:id))
    raise Discourse::NotFound unless group

    result =
      GroupOwnerManager.add(
        guardian,
        group,
        **user_selectors,
        notify_users: params[:notify_users].to_s == "true",
      )

    render json: success_json.merge!(usernames: result[:usernames])
  rescue GroupMutations::AutomaticGroup => error
    render_json_error(error.message)
  end

  def join
    ensure_logged_in

    group = find_group_for_show
    raise Discourse::NotFound unless group

    GroupSelfMembership.join(guardian, group)
  end

  def handle_membership_request
    group = Group.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) if group.blank?
    guardian.ensure_can_edit!(group)

    user = User.find_by(id: params[:user_id])
    raise Discourse::InvalidParameters.new(:user_id) if user.blank?

    GroupMembershipRequestHandler.handle(guardian, group, user, accept: params[:accept].present?)

    render json: success_json
  end

  def mentionable
    group = find_group(:name)

    if group
      render json: { mentionable: Group.mentionable(current_user).where(id: group.id).present? }
    else
      raise Discourse::InvalidAccess.new
    end
  end

  def messageable
    group = find_group(:name)

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

    # maintain backwards compatibility with the singular param names
    result =
      GroupMemberRemover.remove(
        guardian,
        group,
        usernames: params[:username].presence || params[:usernames],
        user_id: params[:user_id],
        user_ids: params[:user_ids],
        user_emails: params[:user_email].presence || params[:user_emails],
      )

    render json:
             success_json.merge!(
               usernames: result[:usernames],
               skipped_usernames: result[:skipped_usernames],
             )
  end

  def leave
    ensure_logged_in

    group = Group.find_by(id: params[:id])
    raise Discourse::NotFound unless group

    GroupSelfMembership.leave(guardian, group)
  end

  def request_membership
    reason = params.require(:reason)
    group = find_group(:name)

    post = GroupMembershipRequester.request(guardian, group, reason)

    render json: success_json.merge(relative_url: post.topic.relative_url)
  rescue GroupMembershipRequester::AlreadyRequested => error
    render json: failed_json.merge(error: error.message), status: :conflict
  end

  def set_notifications
    group = find_group(:name)
    notification_level = params.require(:notification_level)

    user_id = current_user.id
    user_id = params[:user_id] || user_id if guardian.is_staff?

    group_user = GroupUser.find_by(group_id: group.id, user_id: user_id)
    raise Discourse::InvalidParameters.new(:user_id) if group_user.blank?

    group_user.update!(notification_level: notification_level)

    render json: success_json
  end

  def histories
    group = find_group(:name)
    guardian.ensure_can_edit!(group) unless guardian.can_admin_group?(group)

    page_size = 25
    offset = (params[:offset] && params[:offset].to_i) || 0

    group_histories =
      GroupHistory.with_filters(group, params[:filters]).limit(page_size).offset(offset * page_size)

    render_json_dump(
      logs: serialize_data(group_histories, BasicGroupHistorySerializer),
      all_loaded: group_histories.count < page_size,
    )
  end

  def search
    include_everyone =
      (params[:include_everyone] == "true" || params[:include_pseudogroups] == "true") &&
        !SiteSetting.granular_anonymous_and_logged_in_groups_permissions
    include_pseudogroups = params[:include_pseudogroups] == "true"
    groups =
      Group.visible_groups(
        current_user,
        ["name"],
        include_everyone: include_everyone,
        include_pseudogroups: include_pseudogroups,
      ).includes(:flair_upload)

    if (term = params[:term]).present?
      groups =
        groups.where(
          "position(LOWER(:term) IN LOWER(groups.name)) <> 0 OR position(LOWER(:term) IN LOWER(groups.full_name)) <> 0",
          term: term,
        )
    end

    groups = groups.where(automatic: false) if params[:ignore_automatic].to_s == "true"
    groups = DiscoursePluginRegistry.apply_modifier(:groups_search_query, groups, self)

    if Group.preloaded_custom_field_names.present?
      Group.preload_custom_fields(groups, Group.preloaded_custom_field_names)
    end

    render_serialized(groups, BasicGroupSerializer)
  end

  def permissions
    group = find_group(:name)
    category_groups =
      group.category_groups.select do |category_group|
        guardian.can_see_category?(category_group.category)
      end
    render_serialized(
      category_groups.sort_by { |category_group| category_group.category.name },
      CategoryGroupSerializer,
    )
  end

  def test_email_settings
    params.require(:group_id)
    params.require(:protocol)
    params.require(:port)
    params.require(:host)
    params.require(:username)
    params.require(:password)

    group = Group.find(params[:group_id])
    guardian.ensure_can_admin_group!(group)

    RateLimiter.new(current_user, "group_test_email_settings", 5, 1.minute).performed!

    settings = params.except(:name, :protocol)
    email_host = params[:host]

    begin
      FinalDestination::SSRFDetector.lookup_and_filter_ips(email_host)
    rescue FinalDestination::SSRFDetector::DisallowedIpError
      raise Discourse::InvalidParameters.new(I18n.t("email_settings.invalid_host"))
    rescue FinalDestination::SSRFDetector::LookupFailedError
      raise Discourse::InvalidParameters.new(I18n.t("email_settings.host_resolve_failed"))
    end

    if params[:protocol] != "smtp"
      raise Discourse::InvalidParameters.new("Valid protocol to test is smtp")
    end

    hijack do
      raise Discourse::InvalidParameters if params[:ssl_mode].blank?

      settings.delete(:ssl_mode)

      if Group.smtp_ssl_modes.values.exclude?(params[:ssl_mode].to_i)
        raise Discourse::InvalidParameters.new("SSL mode must be valid")
      end

      final_settings =
        settings.merge(
          enable_tls: params[:ssl_mode].to_i == Group.smtp_ssl_modes[:ssl_tls],
          enable_starttls_auto: params[:ssl_mode].to_i == Group.smtp_ssl_modes[:starttls],
        ).permit(:host, :port, :username, :password, :enable_tls, :enable_starttls_auto, :debug)
      EmailSettingsValidator.validate_as_user(
        current_user,
        "smtp",
        **final_settings.to_h.symbolize_keys,
      )

      render json: success_json
    rescue *EmailSettingsExceptionHandler::EXPECTED_EXCEPTIONS, StandardError => err
      render_json_error(EmailSettingsExceptionHandler.friendly_exception_message(err, email_host))
    end
  end

  private

  def user_selectors
    {
      usernames: params[:usernames],
      user_id: params[:user_id],
      user_ids: params[:user_ids],
      user_emails: params[:user_emails],
    }
  end

  # nil when the caller said nothing, so the mutation keeps its own default
  def notify_users_choice
    return nil if !params.key?(:notify_users)
    params[:notify_users].to_s == "true"
  end

  def existing_users_choice
    return nil if params[:update_existing_users].blank?
    params[:update_existing_users] == "true"
  end

  def find_group_for_show(ensure_can_see: true)
    group =
      if params[:id]
        Group.find_by(id: params[:id])
      elsif params[:name]
        Group.find_by("LOWER(name) = ?", params[:name].downcase)
      end

    raise Discourse::NotFound if ensure_can_see && !guardian.can_see_group?(group)
    group
  end

  def find_group(param_name, ensure_can_see: true)
    name = params.require(param_name)

    group = Group.find_by("LOWER(name) = ?", name.downcase)

    raise Discourse::NotFound if ensure_can_see && !guardian.can_see_group?(group)
    group
  end
end
