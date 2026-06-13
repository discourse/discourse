# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::PostSerializer do
  fab!(:group)
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:post) { Fabricate(:post, user: author) }

  before { group.add(author) }

  it "exposes the post author's group ids and names" do
    json = described_class.new(post, scope: Guardian.new(Fabricate(:admin)), root: false).as_json

    expect(json[:author_group_ids]).to include(group.id)
    expect(json[:author_group_names]).to include(group.name)
  end

  it "hides group membership that is not visible to the scope" do
    hidden = Fabricate(:group, members_visibility_level: Group.visibility_levels[:staff])
    hidden.add(author)

    json = described_class.new(post, scope: Guardian.new(Fabricate(:user)), root: false).as_json

    expect(json[:author_group_names]).to include(group.name)
    expect(json[:author_group_names]).not_to include(hidden.name)
    expect(json[:author_group_ids]).not_to include(hidden.id)
  end

  it "exposes restricted group membership to a staff scope" do
    hidden = Fabricate(:group, members_visibility_level: Group.visibility_levels[:staff])
    hidden.add(author)

    json = described_class.new(post, scope: Guardian.new(Fabricate(:admin)), root: false).as_json

    expect(json[:author_group_names]).to include(hidden.name)
  end
end
