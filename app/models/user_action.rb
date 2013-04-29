class UserAction < ActiveRecord::Base
  belongs_to :user
  belongs_to :target_post, class_name: "Post"
  belongs_to :target_topic, class_name: "Topic"
  attr_accessible :acting_user_id, :action_type, :target_topic_id, :target_post_id, :target_user_id, :user_id

  validates_presence_of :action_type
  validates_presence_of :user_id

  LIKE = 1
  WAS_LIKED = 2
  BOOKMARK = 3
  NEW_TOPIC = 4
  POST = 5
  RESPONSE= 6
  MENTION = 7
  QUOTE = 9
  STAR = 10
  EDIT = 11
  NEW_PRIVATE_MESSAGE = 12
  GOT_PRIVATE_MESSAGE = 13

  ORDER = Hash[*[
    NEW_PRIVATE_MESSAGE,
    GOT_PRIVATE_MESSAGE,
    BOOKMARK,
    NEW_TOPIC,
    POST,
    RESPONSE,
    LIKE,
    WAS_LIKED,
    MENTION,
    QUOTE,
    STAR,
    EDIT
  ].each_with_index.to_a.flatten]


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
  pu.email ,pu.username, pu.name, pu.id user_id,
  u.email acting_email, u.username acting_username, u.name acting_name, u.id acting_user_id,
  coalesce(p.cooked, p2.cooked) cooked
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
      data = builder.exec.to_a
    else
      builder.where("a.user_id = :user_id", user_id: user_id.to_i)
      builder.where("a.action_type in (:action_types)", action_types: action_types) if action_types && action_types.length > 0
      builder.order_by("a.created_at desc")
      builder.offset(offset.to_i)
      builder.limit(limit.to_i)
      data = builder.exec.to_a
    end

    data.each do |row|
      row["action_type"] = row["action_type"].to_i
      row["created_at"] = DateTime.parse(row["created_at"])
      # we should probably cache the excerpts in the db at some point
      row["excerpt"] = PrettyText.excerpt(row["cooked"],300) if row["cooked"]
      row["cooked"] = nil
      row["avatar_template"] = User.avatar_template(row["email"])
      row["acting_avatar_template"] = User.avatar_template(row["acting_email"])
      row.delete("email")
      row.delete("acting_email")
      row["slug"] = Slug.for(row["title"])
    end

    data
  end

  def self.log_action!(hash)
    require_parameters(hash, :action_type, :user_id, :acting_user_id, :target_topic_id, :target_post_id)
    transaction(requires_new: true) do
      begin
        action = new(hash)

        if hash[:created_at]
          action.created_at = hash[:created_at]
        end
        action.save!

        action_type = hash[:action_type]
        user_id = hash[:user_id]
        if action_type == LIKE
          User.update_all('likes_given = likes_given + 1', id: user_id)
        elsif action_type == WAS_LIKED
          User.update_all('likes_received = likes_received + 1', id: user_id)
        end

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

    action_type = hash[:action_type]
    user_id = hash[:user_id]
    if action_type == LIKE
      User.update_all('likes_given = likes_given - 1', id: user_id)
    elsif action_type == WAS_LIKED
      User.update_all('likes_received = likes_received - 1', id: user_id)
    end
  end

  protected

  def self.apply_common_filters(builder,user_id,guardian,ignore_private_messages=false)


    unless guardian.can_see_deleted_posts?
      builder.where("p.deleted_at is null and p2.deleted_at is null and t.deleted_at is null")
    end

    unless guardian.user && guardian.user.id == user_id
      builder.where("a.action_type not in (#{BOOKMARK})")
    end

    if !guardian.can_see_private_messages?(user_id) || ignore_private_messages
      builder.where("t.archetype != :archetype", archetype: Archetype::private_message)
    end

    unless guardian.is_moderator?
      allowed = guardian.secure_category_ids
      if allowed.present?
        builder.where("( c.secure IS NULL OR
                         c.secure = 'f' OR
                        (c.secure = 't' and c.id in (:cats)) )", cats: guardian.secure_category_ids )
      else
        builder.where("(c.secure IS NULL OR c.secure = 'f')")
      end
    end
  end

  def self.require_parameters(data, *params)
    params.each do |p|
      raise Discourse::InvalidParameters.new(p) if data[p].nil?
    end
  end
end
