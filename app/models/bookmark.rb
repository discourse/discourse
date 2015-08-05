
class Bookmark < PostAction
  include PostActionSubclassMixin

  self.table_name = :bookmarks
  self.pa_type = PostActionType.bookmark

  before_create do
    raise AlreadyActed if PostAction.where(user_id: user_id)
                            .where(post_id: post_id)
                            .where(post_action_type_id: pa_type)
                            .where(deleted_at: nil)
                            .exists?
  end

  def is_bookmark?
    true
  end

  def is_like?
    false
  end

  def is_flag?
    false
  end

  def is_private_message?
    false
  end

end

# == Schema Information
#
# Table name: bookmarks
#
#  id                  :integer          primary key
#  post_id             :integer
#  user_id             :integer
#  created_at          :datetime
#  updated_at          :datetime
#  deleted_by_id       :integer
#  deleted_at          :datetime
#  post_action_type_id :integer
#
