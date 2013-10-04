class UserAction < ActiveRecord::Base
  belongs_to :user
  belongs_to :target_post, class_name: "Post"
  belongs_to :target_topic, class_name: "Topic"

  validates_presence_of :action_type
  validates_presence_of :user_id

  LIKE = 1
  WAS_LIKED = 2
  BOOKMARK = 3
  NEW_TOPIC = 4
  REPLY = 5
  RESPONSE= 6
  MENTION = 7
  QUOTE = 9
  STAR = 10
  EDIT = 11
  NEW_PRIVATE_MESSAGE = 12
  GOT_PRIVATE_MESSAGE = 13

  ORDER = Hash[*[
    GOT_PRIVATE_MESSAGE,
    NEW_PRIVATE_MESSAGE,
    NEW_TOPIC,
    REPLY,
    RESPONSE,
    LIKE,
    WAS_LIKED,
    MENTION,
    QUOTE,
    BOOKMARK,
    STAR,
    EDIT
  ].each_with_index.to_a.flatten]

  # note, this is temporary until we upgrade to rails 4
  #  in rails 4 types are mapped correctly so you dont end up
  #  having strings where you would expect bools
  class UserActionRow < OpenStruct
    include ActiveModel::SerializerSupport
  end


  def self.stats(user_id, guardian)

    # Sam: I tried this in AR and it got complex
    builder = UserAction.sql_builder <<SQL

    SELECT action_type, COUNT(*) count
    FROM user_actions a
    JOIN topics t ON t.id = a.target_topic_id
    LEFT JOIN posts p on p.id = a.target_post_id
    JOIN posts p2 on p2.topic_id = a.target_topic_id and p2.post_number = 1
    LEFT JOIN categories c ON c.id = t.category_id
    /*where*/
    GROUP BY action_type
SQL


    builder.where('a.user_id = :user_id', user_id: user_id)

    apply_common_filters(builder, user_id, guardian)

    results = builder.exec.to_a
    results.sort! { |a,b| ORDER[a.action_type] <=> ORDER[b.action_type] }

    results
  end

  def self.stream_item(action_id, guardian)
    stream(action_id: action_id, guardian: guardian).first
  end

  def self.stream(opts={})
    user_id = opts[:user_id]
    offset = opts[:offset] || 0
    limit = opts[:limit] || 60
    action_id = opts[:action_id]
    action_types = opts[:action_types]
    guardian = opts[:guardian]
    ignore_private_messages = opts[:ignore_private_messages]

    # The weird thing is that target_post_id can be null, so it makes everything
    #  ever so more complex. Should we allow this, not sure.

    builder = SqlBuilder.new("
SELECT
  t.title, a.action_type, a.created_at, t.id topic_id,
  a.user_id AS target_user_id, au.name AS target_name, au.username AS target_username,
  coalesce(p.post_number, 1) post_number,
  p.reply_to_post_number,
  pu.email, pu.username, pu.name, pu.id user_id,
  pu.use_uploaded_avatar, pu.uploaded_avatar_template, pu.uploaded_avatar_id,
  u.email acting_email, u.username acting_username, u.name acting_name, u.id acting_user_id,
  u.use_uploaded_avatar acting_use_uploaded_avatar, u.uploaded_avatar_template acting_uploaded_avatar_template, u.uploaded_avatar_id acting_uploaded_avatar_id,
  coalesce(p.cooked, p2.cooked) cooked,
  CASE WHEN coalesce(p.deleted_at, p2.deleted_at, t.deleted_at) IS NULL THEN false ELSE true END deleted,
  p.hidden,
  p.post_type
FROM user_actions as a
JOIN topics t on t.id = a.target_topic_id
LEFT JOIN posts p on p.id = a.target_post_id
JOIN posts p2 on p2.topic_id = a.target_topic_id and p2.post_number = 1
JOIN users u on u.id = a.acting_user_id
JOIN users pu on pu.id = COALESCE(p.user_id, t.user_id)
JOIN users au on au.id = a.user_id
LEFT JOIN categories c on c.id = t.category_id
/*where*/
/*order_by*/
/*offset*/
/*limit*/
")

    apply_common_filters(builder, user_id, guardian, ignore_private_messages)

    if action_id
      builder.where("a.id = :id", id: action_id.to_i)
    else
      builder.where("a.user_id = :user_id", user_id: user_id.to_i)
      builder.where("a.action_type in (:action_types)", action_types: action_types) if action_types && action_types.length > 0
      builder
        .order_by("a.created_at desc")
        .offset(offset.to_i)
        .limit(limit.to_i)
    end

    builder.map_exec(UserActionRow)
  end

  def self.log_action!(hash)
    required_parameters = [:action_type, :user_id, :acting_user_id, :target_topic_id, :target_post_id]
    require_parameters(hash, *required_parameters)
    transaction(requires_new: true) do
      begin

        # TODO there are conditions when this is called and user_id was already rolled back and is invalid.

        # protect against dupes, for some reason this is failing in some cases
        action = self.where(hash.select{|k,v| required_parameters.include?(k)}).first
        return action if action

        action = self.new(hash)

        if hash[:created_at]
          action.created_at = hash[:created_at]
        end
        action.save!

        user_id = hash[:user_id]
        update_like_count(user_id, hash[:action_type], 1)

        topic = Topic.includes(:category).where(id: hash[:target_topic_id]).first

        # move into Topic perhaps
        group_ids = nil
        if topic && topic.category && topic.category.read_restricted
          group_ids = topic.category.groups.pluck("groups.id")
        end

        if action.user
          MessageBus.publish("/users/#{action.user.username.downcase}",
                                action.id,
                                user_ids: [user_id],
                                group_ids: group_ids )
        end

        action

      rescue ActiveRecord::RecordNotUnique
        # can happen, don't care already logged
        raise ActiveRecord::Rollback
      end
    end
  end

  def self.remove_action!(hash)
    require_parameters(hash, :action_type, :user_id, :acting_user_id, :target_topic_id, :target_post_id)
    if action = UserAction.where(hash).first
      action.destroy
      MessageBus.publish("/user/#{hash[:user_id]}", {user_action_id: action.id, remove: true})
    end

    update_like_count(hash[:user_id], hash[:action_type], -1)
  end

  def self.synchronize_target_topic_ids(post_ids = nil)

    # nuke all dupes, using magic
    builder = SqlBuilder.new <<SQL
DELETE FROM user_actions USING user_actions ua2
/*where*/
SQL

    builder.where <<SQL
  user_actions.action_type = ua2.action_type AND
  user_actions.user_id = ua2.user_id AND
  user_actions.acting_user_id = ua2.acting_user_id AND
  user_actions.target_post_id = ua2.target_post_id AND
  user_actions.target_post_id > 0 AND
  user_actions.id > ua2.id
SQL

    if post_ids
      builder.where("user_actions.target_post_id in (:post_ids)", post_ids: post_ids)
    end

    builder.exec

    builder = SqlBuilder.new("UPDATE user_actions
                    SET target_topic_id = (select topic_id from posts where posts.id = target_post_id)
                    /*where*/")

    builder.where("target_topic_id <> (select topic_id from posts where posts.id = target_post_id)")
    if post_ids
      builder.where("target_post_id in (:post_ids)", post_ids: post_ids)
    end

    builder.exec
  end

  def self.synchronize_favorites
    exec_sql("
    DELETE FROM user_actions ua
    WHERE action_type = :star
      AND NOT EXISTS (
        SELECT 1 FROM topic_users tu
        WHERE
              tu.user_id = ua.user_id AND
              tu.topic_id = ua.target_topic_id AND
              starred
      )", star: UserAction::STAR)

    exec_sql("INSERT INTO user_actions
             (action_type, user_id, target_topic_id, target_post_id, acting_user_id, created_at, updated_at)
             SELECT :star, tu.user_id, tu.topic_id, -1, tu.user_id, tu.starred_at, tu.starred_at
             FROM topic_users tu
             WHERE starred AND NOT EXISTS(
              SELECT 1 FROM user_actions ua
              WHERE tu.user_id = ua.user_id AND
                    tu.topic_id = ua.target_topic_id AND
                    ua.action_type = :star
             )
             ", star: UserAction::STAR)

  end

  def self.ensure_consistency!
    self.synchronize_target_topic_ids
    self.synchronize_favorites
  end

  protected

  def self.update_like_count(user_id, action_type, delta)
    if action_type == LIKE
      UserStat.where(user_id: user_id).update_all("likes_given = likes_given + #{delta.to_i}")
    elsif action_type == WAS_LIKED
      UserStat.where(user_id: user_id).update_all("likes_received = likes_received + #{delta.to_i}")
    end
  end

  def self.apply_common_filters(builder,user_id,guardian,ignore_private_messages=false)

    unless guardian.can_see_deleted_posts?
      builder.where("p.deleted_at is null and p2.deleted_at is null and t.deleted_at is null")
    end

    unless (guardian.user && guardian.user.id == user_id) || guardian.is_staff?
      builder.where("a.action_type not in (#{BOOKMARK},#{STAR})")
    end

    if !guardian.can_see_private_messages?(user_id) || ignore_private_messages
      builder.where("t.archetype != :archetype", archetype: Archetype::private_message)
    end

    unless guardian.is_staff?
      allowed = guardian.secure_category_ids
      if allowed.present?
        builder.where("( c.read_restricted IS NULL OR
                         NOT c.read_restricted OR
                        (c.read_restricted and c.id in (:cats)) )", cats: guardian.secure_category_ids )
      else
        builder.where("(c.read_restricted IS NULL OR NOT c.read_restricted)")
      end
    end
  end

  def self.require_parameters(data, *params)
    params.each do |p|
      raise Discourse::InvalidParameters.new(p) if data[p].nil?
    end
  end
end

# == Schema Information
#
# Table name: user_actions
#
#  id              :integer          not null, primary key
#  action_type     :integer          not null
#  user_id         :integer          not null
#  target_topic_id :integer
#  target_post_id  :integer
#  target_user_id  :integer
#  acting_user_id  :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  idx_unique_rows                           (action_type,user_id,target_topic_id,target_post_id,acting_user_id) UNIQUE
#  index_actions_on_acting_user_id           (acting_user_id)
#  index_actions_on_user_id_and_action_type  (user_id,action_type)
#

