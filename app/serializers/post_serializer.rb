class PostSerializer < ApplicationSerializer

  # To pass in additional information we might need
  attr_accessor :topic_slug
  attr_accessor :topic_view
  attr_accessor :parent_post
  attr_accessor :add_raw
  attr_accessor :single_post_link_counts
  attr_accessor :draft_sequence

  attributes :id,
             :post_number,
             :post_type,
             :created_at,
             :updated_at,
             :reply_count,
             :reply_to_post_number,
             :quote_count,
             :avg_time,
             :incoming_link_count,
             :reads,
             :score,
             :yours,
             :topic_slug,
             :topic_id,
             :display_username,
             :version,
             :can_edit,
             :can_delete,
             :can_recover,
             :link_counts,
             :cooked,
             :read,
             :username,
             :name,
             :reply_to_user,
             :bookmarked,
             :raw,
             :actions_summary,
             :moderator?,
             :avatar_template,
             :user_id,
             :draft_sequence,
             :hidden,
             :hidden_reason_id,
             :deleted_at, 
             :trust_level


  def moderator?
    object.user.moderator?
  end

  def avatar_template
    object.user.avatar_template
  end

  def yours
    scope.user == object.user
  end

  def can_edit
    scope.can_edit?(object)
  end

  def can_delete
    scope.can_delete?(object)
  end

  def can_recover
    scope.can_recover_post?(object)
  end

  def link_counts

    return @single_post_link_counts if @single_post_link_counts.present?

    # TODO: This could be better, just porting the old one over
    @topic_view.link_counts[object.id].map do |link|
      result = {}
      result[:url] = link[:url]
      result[:internal] = link[:internal]
      result[:reflection] = link[:reflection]
      result[:title] = link[:title] if link[:title].present?
      result[:clicks] = link[:clicks] || 0
      result
    end
  end

  def cooked
    if object.hidden && !scope.is_staff?
      if scope.current_user && object.user_id == scope.current_user.id
        I18n.t('flagging.you_must_edit')
      else
        I18n.t('flagging.user_must_edit')
      end
    else
      object.filter_quotes(@parent_post)
    end
  end

  def read
    @topic_view.read?(object.post_number)
  end

  def score
    object.score || 0
  end

  def display_username
    object.user.name
  end

  def version
    object.cached_version
  end

  def username
    object.user.username
  end

  def name
    object.user.name
  end

  def trust_level
    object.user.trust_level
  end

  def reply_to_user
    {
      username: object.reply_to_user.username,
      name: object.reply_to_user.name
    }
  end

  def bookmarked
    true
  end

  # Summary of the actions taken on this post
  def actions_summary
    result = []
    PostActionType.types.each do |sym, id|
      next if [:bookmark].include?(sym)
      count_col = "#{sym}_count".to_sym

      count = object.send(count_col) if object.respond_to?(count_col)
      count ||= 0
      action_summary = {id: id,
                        count: count,
                        hidden: (sym == :vote),
                        can_act: scope.post_can_act?(object, sym, taken_actions: post_actions)}

      # The following only applies if you're logged in
      if action_summary[:can_act] && scope.current_user.present?
        action_summary[:can_clear_flags] = scope.is_staff? && PostActionType.flag_types.values.include?(id)
      end

      if post_actions.present? && post_actions.has_key?(id)
        action_summary[:acted] = true
        action_summary[:can_undo] = scope.can_delete?(post_actions[id])
      end

      # anonymize flags
      if !scope.is_staff? && PostActionType.flag_types.values.include?(id)
        action_summary[:count] = action_summary[:acted] ? 1 : 0
      end

      result << action_summary
    end

    result
  end

  def include_draft_sequence?
    @draft_sequence.present?
  end

  def include_slug_title?
    @topic_slug.present?
  end

  def include_raw?
    @add_raw.present?
  end

  def include_link_counts?
    return true if @single_post_link_counts.present?

    @topic_view.present? && @topic_view.link_counts.present? && @topic_view.link_counts[object.id].present?
  end

  def include_read?
    @topic_view.present?
  end

  def include_reply_to_user?
    object.quoteless? && object.reply_to_user
  end

  def include_bookmarked?
    post_actions.present? && post_actions.keys.include?(PostActionType.types[:bookmark])
  end

  private

  def post_actions
    @post_actions ||= (@topic_view.present? && @topic_view.all_post_actions.present?) ? @topic_view.all_post_actions[object.id] : nil
  end
end
