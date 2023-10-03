# frozen_string_literal: true

RSpec.describe PosterSerializer do
  let(:poster) { Fabricate(:user, admin: false, moderator: false) }

  it "serializes the correct attributes" do
    expect(PosterSerializer.new(poster).attributes.keys).to contain_exactly(
      :trust_level,
      :avatar_template,
      :id,
      :name,
      :username,
    )
  end

  it "includes group flair attributes when appropriate" do
    group =
      Fabricate(
        :group,
        name: "Groupster",
        flair_bg_color: "#111111",
        flair_color: "#999999",
        flair_icon: "icon",
      )
    groupie = Fabricate(:user, flair_group: group)

    expect(PosterSerializer.new(groupie).attributes.keys).to contain_exactly(
      :trust_level,
      :avatar_template,
      :id,
      :name,
      :username,
      :flair_bg_color,
      :flair_color,
      :flair_group_id,
      :flair_name,
      :flair_url,
    )
  end
end
