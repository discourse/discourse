# frozen_string_literal: true

RSpec.describe TopicPostCountSerializer do
  fab!(:flair_group) do
    Fabricate(:group, flair_bg_color: "#111111", flair_color: "#999999", flair_icon: "icon")
  end
  fab!(:flair_user) { Fabricate(:user, flair_group: flair_group) }
  fab!(:allowed_group, :group)

  let(:flair_keys) { %i[flair_name flair_url flair_bg_color flair_color flair_group_id] }

  def flair_present_for?(scope)
    json =
      described_class.new({ user: flair_user, post_count: 1 }, scope: scope, root: false).as_json
    flair_keys.any? { |key| json.key?(key) }
  end

  it "includes flair for any viewer when the everyone group is configured" do
    SiteSetting.flair_visible_groups = Group::AUTO_GROUPS[:everyone].to_s

    expect(flair_present_for?(Guardian.new)).to eq(true)
  end

  it "omits flair for non-members and anonymous viewers when restricted" do
    SiteSetting.flair_visible_groups = allowed_group.id.to_s
    member = Fabricate(:user, groups: [allowed_group])

    expect(flair_present_for?(Guardian.new(member))).to eq(true)
    expect(flair_present_for?(Guardian.new(Fabricate(:user)))).to eq(false)
    expect(flair_present_for?(Guardian.new)).to eq(false)
  end
end
