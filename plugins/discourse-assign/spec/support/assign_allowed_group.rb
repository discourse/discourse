# frozen_string_literal: true

shared_context "with group that is allowed to assign" do
  fab!(:assign_allowed_group) do
    Fabricate(:group, assignable_level: Group::ALIAS_LEVELS[:everyone])
  end

  before { SiteSetting.assign_allowed_on_groups += "|#{assign_allowed_group.id}" }
end
