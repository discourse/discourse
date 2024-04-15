# frozen_string_literal: true

class ComposerController < ApplicationController
  requires_login

  def mentions
    @names = params.require(:names)
    raise Discourse::InvalidParameters.new(:names) if !@names.kind_of?(Array) || @names.size > 20

    if params[:topic_id].present?
      @topic = Topic.find_by(id: params[:topic_id])
      guardian.ensure_can_see!(@topic)
    end

    # allowed_names is necessary just for new private messages.
    @allowed_names =
      if params[:allowed_names].present?
        raise Discourse.InvalidParameters(:allowed_names) if !params[:allowed_names].is_a?(Array)
        params[:allowed_names] << current_user.username
      else
        []
      end

    user_reasons = {}
    group_reasons = {}
    @names.each do |name|
      if user = users[name]
        reason = user_reason(user)
        user_reasons[name] = reason if reason.present?
      elsif group = groups[name]
        reason = group_reason(group)
        group_reasons[name] = reason if reason.present?
      end
    end

    if @topic && @names.include?(SiteSetting.here_mention) && guardian.can_mention_here?
      here_count =
        PostAlerter.new.expand_here_mention(@topic.first_post, exclude_ids: [current_user.id]).size
    end

    serialized_groups =
      groups
        .values
        .reduce({}) do |hash, group|
          serialized_group = { user_count: group.user_count }

          if group_reasons[group.name] == :not_allowed &&
               members_visible_group_ids.include?(group.id) &&
               (@topic&.private_message? || @allowed_names.present?)
            # Find users that are notified already because they have been invited
            # directly or via a group
            notified_count =
              GroupUser
                # invited directly
                .where(user_id: topic_allowed_user_ids)
                .or(
                  # invited via a group
                  GroupUser.where(
                    user_id: GroupUser.where(group_id: topic_allowed_group_ids).select(:user_id),
                  ),
                )
                .where(group_id: group.id)
                .select(:user_id)
                .distinct
                .count

            if notified_count > 0
              if notified_count == group.user_count
                group_reasons.delete(group.name)
              else
                group_reasons[group.name] = :some_not_allowed
                serialized_group[:notified_count] = notified_count
              end
            end
          end

          hash[group.name] = serialized_group
          hash
        end

    render json: {
             users: users.keys,
             user_reasons: user_reasons,
             groups: serialized_groups,
             group_reasons: group_reasons,
             here_count: here_count,
             max_users_notified_per_group_mention: SiteSetting.max_users_notified_per_group_mention,
           }
  end

  private

  def user_reason(user)
    reason =
      if @topic && !user.guardian.can_see?(@topic)
        @topic.private_message? ? :private : :category
      elsif @allowed_names.present? &&
            !is_user_allowed?(user, topic_allowed_user_ids, topic_allowed_group_ids)
        # This would normally be handled by the previous if, but that does not work for new private messages.
        :private
      elsif topic_muted_by.include?(user.id)
        :muted_topic
      elsif @topic&.private_message? &&
            !is_user_allowed?(user, topic_allowed_user_ids, topic_allowed_group_ids)
        # Admins can see the topic, but they will not be mentioned if they were not invited.
        :not_allowed
      end

    # Non-staff users can see only basic information why the users cannot see the topic.
    reason = nil if !guardian.is_staff? && reason != :private && reason != :category

    reason
  end

  def group_reason(group)
    if !mentionable_group_ids.include?(group.id)
      :not_mentionable
    elsif (@topic&.private_message? || @allowed_names.present?) &&
          !topic_allowed_group_ids.include?(group.id)
      :not_allowed
    end
  end

  def is_user_allowed?(user, user_ids, group_ids)
    user_ids.include?(user.id) || user.group_ids.any? { |group_id| group_ids.include?(group_id) }
  end

  def users
    @users ||=
      User.not_staged.where(username_lower: @names.map(&:downcase)).index_by(&:username_lower)
  end

  def groups
    @groups ||=
      Group
        .visible_groups(current_user)
        .where("lower(name) IN (?)", @names.map(&:downcase))
        .index_by(&:name)
  end

  def mentionable_group_ids
    @mentionable_group_ids ||=
      Group.mentionable(current_user, include_public: false).where(name: @names).pluck(:id).to_set
  end

  def members_visible_group_ids
    @members_visible_group_ids ||=
      Group.members_visible_groups(current_user).where(name: @names).pluck(:id).to_set
  end

  def topic_muted_by
    @topic_muted_by ||=
      if @topic.present?
        TopicUser
          .where(topic: @topic)
          .where(user_id: users.values.map(&:id))
          .where(notification_level: TopicUser.notification_levels[:muted])
          .pluck(:user_id)
          .to_set
      else
        Set.new
      end
  end

  def topic_allowed_user_ids
    @topic_allowed_user_ids ||=
      if @allowed_names.present?
        User.where(username_lower: @allowed_names.map(&:downcase)).pluck(:id).to_set
      elsif @topic&.private_message?
        TopicAllowedUser.where(topic: @topic).pluck(:user_id).to_set
      end
  end

  def topic_allowed_group_ids
    @topic_allowed_group_ids ||=
      if @allowed_names.present?
        Group.messageable(current_user).where(name: @allowed_names).pluck(:id).to_set
      elsif @topic&.private_message?
        TopicAllowedGroup.where(topic: @topic).pluck(:group_id).to_set
      end
  end
end
