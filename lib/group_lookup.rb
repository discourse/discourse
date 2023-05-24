# frozen_string_literal: true

class GroupLookup
  def initialize(group_ids = [])
    @group_ids = group_ids.tap(&:compact!).tap(&:uniq!).tap(&:flatten!)
  end

  # Lookup a group by id
  def [](group_id)
    group_names[group_id]
  end

  private

  def group_names
    @group_names ||= Group.where(id: @group_ids).pluck(:id, :name).to_h
  end
end
