# frozen_string_literal: true

shared_context "with group that is allowed to assign" do
  fab!(:assign_allowed_group) do
    Fabricate(:group, assignable_level: Group::ALIAS_LEVELS[:everyone])
  end

  before { SiteSetting.assign_allowed_on_groups += "|#{assign_allowed_group.id}" }

  def add_to_assign_allowed_group(user)
    assign_allowed_group.add(user)
  end

  def get_assigned_allowed_group
    assign_allowed_group
  end

  def get_assigned_allowed_group_name
    assign_allowed_group.name
  end
end
