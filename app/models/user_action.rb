require_dependency 'message_bus'
require_dependency 'sql_builder'

class UserAction < ActiveRecord::Base
  belongs_to :user
  belongs_to :target_post, :class_name => "Post"
  belongs_to :target_topic, :class_name => "Topic"
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
    results = UserAction.select("action_type, COUNT(*) count, '' AS description")
      .joins(:target_topic)
      .where(user_id: user_id)
      .group('action_type')

    # We apply similar filters in stream, might consider trying to consolidate somehow
    unless guardian.can_see_private_messages?(user_id)
      results = results.where('topics.archetype <> ?', Archetype::private_message)
    end

    unless guardian.user && guardian.user.id == user_id
      results = results.where("action_type <> ?", BOOKMARK)
    end

    results = results.to_a

    results.sort! { |a,b| ORDER[a.action_type] <=> ORDER[b.action_type] }
    results.each do |row|
      row.description = self.description(row.action_type, detailed: true)
    end

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
/*where*/
/*order_by*/
/*offset*/
/*limit*/
")

    unless guardian.can_see_deleted_posts?
      builder.where("p.deleted_at is null and p2.deleted_at is null")
    end

    unless guardian.user && guardian.user.id == user_id
      builder.where("a.action_type not in (#{BOOKMARK})")
    end

    if !guardian.can_see_private_messages?(user_id) || ignore_private_messages
      builder.where("t.archetype != :archetype", archetype: Archetype::private_message)
    end

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
      row["description"] = self.description(row["action_type"])
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

  def self.description(row, opts = {})
    t = I18n.t('user_action_descriptions')
    if opts[:detailed]
      # will localize as soon as we stablize the names here
      desc = case row.to_i
      when BOOKMARK
        t[:bookmarks]
      when NEW_TOPIC
        t[:topics]
      when WAS_LIKED
        t[:likes_received]
      when LIKE
        t[:likes_given]
      when RESPONSE
        t[:responses]
      when POST
        t[:posts]
      when MENTION
        t[:mentions]
      when QUOTE
        t[:quotes]
      when EDIT
        t[:edits]
      when STAR
        t[:favorites]
      when NEW_PRIVATE_MESSAGE
        t[:sent_items]
      when GOT_PRIVATE_MESSAGE
        t[:inbox]
      end
    else
      desc =
      case row.to_i
      when NEW_TOPIC
        then t[:posted]
      when LIKE,WAS_LIKED
        then t[:liked]
      when RESPONSE,POST
        then t[:responded_to]
      when BOOKMARK
        then t[:bookmarked]
      when MENTION
        then t[:mentioned]
      when QUOTE
        then t[:quoted]
      when STAR
        then t[:favorited]
      when EDIT
        then t[:edited]
      end
    end
    desc
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
  end

  protected
  def self.require_parameters(data, *params)
    params.each do |p|
      raise Discourse::InvalidParameters.new(p) if data[p].nil?
    end
  end
end
