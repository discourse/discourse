# frozen_string_literal: true

describe PostLocalizationUpdater do
  fab!(:user)
  fab!(:post) { Fabricate(:post, version: 99) }
  fab!(:group)
  fab!(:post_localization) do
    Fabricate(:post_localization, post: post, locale: "ja", raw: "古いバージョン")
  end

  let(:locale) { "ja" }
  let(:new_raw) { "新しいバージョンです" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
  end

  it "updates an existing localization" do
    localization =
      described_class.update(post_id: post.id, locale: locale, raw: new_raw, user: user)

    expect(localization).to have_attributes(
      raw: new_raw,
      cooked: PrettyText.cook(new_raw),
      localizer_user_id: user.id,
      post_version: post.version,
    )
  end

  it "raises not found if the localization is missing" do
    expect {
      described_class.update(post_id: post.id, locale: "nope", raw: new_raw, user: user)
    }.to raise_error(Discourse::NotFound)
  end

  it "raises not found if the post is missing" do
    expect {
      described_class.update(post_id: -1, locale: locale, raw: new_raw, user: user)
    }.to raise_error(Discourse::NotFound)
  end
end
