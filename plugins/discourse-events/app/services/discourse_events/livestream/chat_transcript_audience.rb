# frozen_string_literal: true

# Decides whether a livestream's chat can be posted to its topic: only when
# everyone able to read the topic could already read the chat. Compares groups
# rather than members, so it errs towards keeping the chat out of the topic.
class DiscourseEvents::Livestream::ChatTranscriptAudience
  AUTO_GROUPS = Group::AUTO_GROUPS
  ALL_LOGGED_IN_USERS = AUTO_GROUPS.values_at(:everyone, :logged_in_users, :trust_level_0)
  TRUST_LEVEL_GROUPS = AUTO_GROUPS.values_at(*(0..4).map { |level| :"trust_level_#{level}" })

  def initialize(event, channel:)
    @event = event
    @channel = channel
  end

  def matches_topic_readers?
    topic_reader_group_ids.all? do |group_id|
      chat_audiences.all? { |allowed_ids| covers?(allowed_ids, group_id) }
    end
  end

  private

  # Everyone is split into its anonymous and logged in halves, since chat can
  # admit one without the other.
  def topic_reader_group_ids
    category = @event.post.topic.category
    group_ids = category&.read_restricted? ? category.secure_group_ids : [AUTO_GROUPS[:everyone]]

    group_ids.flat_map do |id|
      case id
      when AUTO_GROUPS[:everyone]
        [AUTO_GROUPS[:logged_in_users], *anonymous_readers]
      when AUTO_GROUPS[:anonymous_users]
        anonymous_readers
      else
        [id]
      end
    end
  end

  def anonymous_readers
    SiteSetting.login_required ? [] : [AUTO_GROUPS[:anonymous_users]]
  end

  # Each set must allow a reader for them to have seen the chat. The channel
  # keeps the category it was created in, even if the topic has since moved.
  def chat_audiences
    audiences = [SiteSetting.chat_allowed_groups_map]
    audiences << invited_group_ids if @event.private?
    audiences << channel_category_group_ids if channel_category&.read_restricted?
    audiences
  end

  def channel_category
    @channel.chatable if @channel.chatable.is_a?(Category)
  end

  def channel_category_group_ids
    channel_category.secure_group_ids
  end

  def invited_group_ids
    Group.where(name: @event.raw_invitees).pluck(:id)
  end

  def covers?(allowed_ids, group_id)
    # Mirrors `Chat.anonymous_public_channel_access_allowed?`.
    if group_id == AUTO_GROUPS[:anonymous_users]
      return SiteSetting.enable_public_channels && allowed_ids.include?(group_id)
    end

    return true if allowed_ids.include?(group_id) || allowed_ids.intersect?(ALL_LOGGED_IN_USERS)

    case group_id
    when *TRUST_LEVEL_GROUPS
      allowed_ids.any? { |id| TRUST_LEVEL_GROUPS.include?(id) && id <= group_id }
    when AUTO_GROUPS[:staff]
      allowed_ids.include?(AUTO_GROUPS[:admins]) && allowed_ids.include?(AUTO_GROUPS[:moderators])
    else
      false
    end
  end
end
