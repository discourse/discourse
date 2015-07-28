
class Flag < PostAction

  self.table_name = :flags

  validates_presence_of :post_action_type_id

  # === BEGIN CRAZY SUBCLASSING MADNESS === #

  def self.sti_name
    # apparently this works lol
    PostActionType.all_flag_type_ids
  end

  def self.type_condition(table = arel_table)
    table[:post_action_type_id].in(PostActionType.all_flag_type_ids)
  end

  def ensure_proper_type
    raise ActiveRecord::ValidationError "Bad post_action_type_id value for Flag" unless
          PostActionType.all_flag_type_ids.include? post_action_type_id
  end

  # === END CRAZY SUBCLASSING MADNESS === #

  before_create do
    raise AlreadyActed if PostAction.where(user_id: user_id)
                            .where(post_id: post_id)
                            .where(post_action_type_id: PostActionType.all_flag_type_ids)
                            .where(deleted_at: nil)
                            .where(disagreed_at: nil)
                            .where(targets_topic: targets_topic)
                            .exists?
  end

  def is_bookmark?
    false
  end

  def is_like?
    false
  end

  def is_flag?
    true
  end

  def is_private_message?
    post_action_type_id == PostActionType.types[:notify_user] ||
    post_action_type_id == PostActionType.types[:notify_moderators]
  end

end

# == Schema Information
#
# Table name: flags
#
#  id                  :integer          primary key
#  post_id             :integer
#  user_id             :integer
#  post_action_type_id :integer
#  deleted_at          :datetime
#  created_at          :datetime
#  updated_at          :datetime
#  deleted_by_id       :integer
#  related_post_id     :integer
#  staff_took_action   :boolean
#  deferred_by_id      :integer
#  targets_topic       :boolean
#  agreed_at           :datetime
#  agreed_by_id        :integer
#  deferred_at         :datetime
#  disagreed_at        :datetime
#  disagreed_by_id     :integer
#
