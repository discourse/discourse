# frozen_string_literal: true

class Chat::ChatChannelsController < Chat::ChatBaseController
  before_action :set_channel_and_chatable_with_access_check, except: %i[index create search]

  def index
    structured = Chat::ChatChannelFetcher.structured(guardian)
    render_serialized(structured, ChatChannelIndexSerializer, root: false)
  end

  def show
    render_serialized(
      @chat_channel,
      ChatChannelSerializer,
      membership: @chat_channel.membership_for(current_user),
      root: false,
    )
  end

  def follow
    membership = @chat_channel.add(current_user)

    render_serialized(@chat_channel, ChatChannelSerializer, membership: membership, root: false)
  end

  def unfollow
    membership = @chat_channel.remove(current_user)

    render_serialized(@chat_channel, ChatChannelSerializer, membership: membership, root: false)
  end

  def create
    params.require(%i[id name])
    guardian.ensure_can_create_chat_channel!
    if params[:name].length > SiteSetting.max_topic_title_length
      raise Discourse::InvalidParameters.new(:name)
    end

    exists =
      ChatChannel.exists?(chatable_type: "Category", chatable_id: params[:id], name: params[:name])
    if exists
      raise Discourse::InvalidParameters.new(I18n.t("chat.errors.channel_exists_for_category"))
    end

    chatable = Category.find_by(id: params[:id])
    raise Discourse::NotFound unless chatable

    auto_join_users = ActiveRecord::Type::Boolean.new.deserialize(params[:auto_join_users]) || false

    chat_channel =
      chatable.create_chat_channel!(
        name: params[:name],
        description: params[:description],
        user_count: 1,
        auto_join_users: auto_join_users,
      )
    chat_channel.user_chat_channel_memberships.create!(user: current_user, following: true)

    if chat_channel.auto_join_users
      Chat::ChatChannelMembershipManager.new(chat_channel).enforce_automatic_channel_memberships
    end

    render_serialized(
      chat_channel,
      ChatChannelSerializer,
      membership: chat_channel.membership_for(current_user),
    )
  end

  def edit
    guardian.ensure_can_edit_chat_channel!
    if (params[:name]&.length || 0) > SiteSetting.max_topic_title_length
      raise Discourse::InvalidParameters.new(:name)
    end

    chat_channel = ChatChannel.find_by(id: params[:chat_channel_id])
    raise Discourse::NotFound unless chat_channel

    chat_channel.name = params[:name] if params[:name]
    chat_channel.description = params[:description] if params[:description]
    chat_channel.save!

    ChatPublisher.publish_chat_channel_edit(chat_channel, current_user)
    render_serialized(
      chat_channel,
      ChatChannelSerializer,
      membership: chat_channel.membership_for(current_user),
    )
  end

  def search
    params.require(:filter)
    filter = params[:filter]&.downcase
    memberships = Chat::ChatChannelMembershipManager.all_for_user(current_user)
    public_channels =
      Chat::ChatChannelFetcher.secured_public_channels(
        guardian,
        memberships,
        filter: filter,
        status: :open,
      )

    users = User.joins(:user_option).where.not(id: current_user.id)
    if !Chat.allowed_group_ids.include?(Group::AUTO_GROUPS[:everyone])
      users =
        users
          .joins(:groups)
          .where(groups: { id: Chat.allowed_group_ids })
          .or(users.joins(:groups).staff)
    end

    users = users.where(user_option: { chat_enabled: true })
    like_filter = "%#{filter}%"
    if SiteSetting.prioritize_username_in_ux || !SiteSetting.enable_names
      users = users.where("users.username_lower ILIKE ?", like_filter)
    else
      users =
        users.where(
          "LOWER(users.name) ILIKE ? OR users.username_lower ILIKE ?",
          like_filter,
          like_filter,
        )
    end

    users = users.limit(25).uniq

    direct_message_channels =
      (
        if users.count > 0
          ChatChannel
            .includes(chatable: :users)
            .joins(direct_message_channel: :direct_message_users)
            .group(1)
            .having(
              "ARRAY[?] <@ ARRAY_AGG(user_id) AND ARRAY[?] && ARRAY_AGG(user_id)",
              [current_user.id],
              users.map(&:id),
            )
        else
          []
        end
      )

    user_ids_with_channel = []
    direct_message_channels.each do |dm_channel|
      user_ids = dm_channel.chatable.users.map(&:id)
      user_ids_with_channel.concat(user_ids) if user_ids.count < 3
    end

    users_without_channel = users.filter { |u| !user_ids_with_channel.include?(u.id) }

    if current_user.username.downcase.start_with?(filter)
      # We filtered out the current user for the query earlier, but check to see
      # if they should be included, and add.
      users_without_channel << current_user
    end

    render_serialized(
      {
        public_channels: public_channels,
        direct_message_channels: direct_message_channels,
        users: users_without_channel,
        memberships: memberships,
      },
      ChatChannelSearchSerializer,
      root: false,
    )
  end

  def archive
    params.require(:type)

    if params[:type] == "newTopic" ? params[:title].blank? : params[:topic_id].blank?
      raise Discourse::InvalidParameters
    end

    if !guardian.can_change_channel_status?(@chat_channel, :read_only)
      raise Discourse::InvalidAccess.new(I18n.t("chat.errors.channel_cannot_be_archived"))
    end

    Chat::ChatChannelArchiveService.begin_archive_process(
      chat_channel: @chat_channel,
      acting_user: current_user,
      topic_params: {
        topic_id: params[:topic_id],
        topic_title: params[:title],
        category_id: params[:category_id],
        tags: params[:tags],
      },
    )

    render json: success_json
  end

  def retry_archive
    guardian.ensure_can_change_channel_status!(@chat_channel, :archived)

    archive = @chat_channel.chat_channel_archive
    raise Discourse::NotFound if archive.blank?
    raise Discourse::InvalidAccess if !archive.failed?

    Chat::ChatChannelArchiveService.retry_archive_process(chat_channel: @chat_channel)

    render json: success_json
  end

  def change_status
    params.require(:status)

    # we only want to use this endpoint for open/closed status changes,
    # the others are more "special" and are handled by the archive endpoint
    if !ChatChannel.statuses.keys.include?(params[:status]) || params[:status] == "read_only" ||
         params[:status] == "archive"
      raise Discourse::InvalidParameters
    end

    guardian.ensure_can_change_channel_status!(@chat_channel, params[:status].to_sym)
    @chat_channel.public_send("#{params[:status]}!", current_user)

    render json: success_json
  end

  def destroy
    params.require(:channel_name_confirmation)

    guardian.ensure_can_delete_chat_channel!

    if @chat_channel.title(current_user).downcase != params[:channel_name_confirmation].downcase
      raise Discourse::InvalidParameters.new(:channel_name_confirmation)
    end

    begin
      ChatChannel.transaction do
        @chat_channel.trash!(current_user)
        StaffActionLogger.new(current_user).log_custom(
          "chat_channel_delete",
          {
            chat_channel_id: @chat_channel.id,
            chat_channel_name: @chat_channel.title(current_user),
          },
        )
      end
    rescue ActiveRecord::Rollback
      return render_json_error(I18n.t("chat.errors.delete_channel_failed"))
    end

    Jobs.enqueue(:chat_channel_delete, { chat_channel_id: @chat_channel.id })
    render json: success_json
  end
end
