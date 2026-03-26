# frozen_string_literal: true

class GroupManager
  def initialize(group)
    @group = group
  end

  def add(user_ids, automatic: false)
    return [] if user_ids.blank?
    @group.bulk_add(user_ids, automatic:)
  end

  def remove(user_ids)
    return [] if user_ids.blank?
    @group.bulk_remove(user_ids)
  end
end
