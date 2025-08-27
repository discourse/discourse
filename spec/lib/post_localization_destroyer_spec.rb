# frozen_string_literal: true

describe PostLocalizationDestroyer do
  fab!(:user)
  fab!(:post)
  fab!(:group)
  fab!(:localization) { Fabricate(:post_localization, post:, locale: "ja") }

  let(:locale) { "ja" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
  end

  it "deletes the localization" do
    expect {
      described_class.destroy(post_id: post.id, locale: locale, acting_user: user)
    }.to change { PostLocalization.count }.by(-1)
    expect { PostLocalization.find(localization.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "raises not found if the localization is missing" do
    expect {
      described_class.destroy(post_id: post.id, locale: "nope", acting_user: user)
    }.to raise_error(Discourse::NotFound)
  end
end
