# frozen_string_literal: true

describe PostLocalizationCreator do
  fab!(:user)
  fab!(:post)
  fab!(:group)

  let(:locale) { "ja" }
  let(:raw) { "これは翻訳です。" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
  end

  it "creates a post localization record" do
    localization = described_class.create(post_id: post.id, locale:, raw:, user:)

    expect(PostLocalization.find(localization.id)).to have_attributes(
      post_id: post.id,
      locale:,
      raw:,
      localizer_user_id: user.id,
      cooked: PrettyText.cook(raw),
    )
  end

  it "raises not found if the post is missing" do
    expect { described_class.create(post_id: -1, locale:, raw:, user:) }.to raise_error(
      Discourse::NotFound,
    )
  end
end
