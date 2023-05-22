# frozen_string_literal: true

class GroupLookup
  def self.lookup_columns
    @group_lookup_columns ||= %i[id name title full_name automatic]
  end

  def initialize(group_ids = [])
    @group_ids = group_ids.tap(&:compact!).tap(&:uniq!).tap(&:flatten!)
  end

  # Lookup a group by id
  def [](group_id)
    groups[group_id]
  end

  private

  def groups
    @groups ||= Group.where(id: @group_ids).select(self.class.lookup_columns).index_by(&:id)
  end
end
