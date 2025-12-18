# frozen_string_literal: true

describe TagLocalizationUpdater do
  fab!(:user)
  fab!(:tag)
  fab!(:group)
  fab!(:localization) { Fabricate(:tag_localization, tag: tag, locale: "ja", name: "古い猫") }

  let(:locale) { "ja" }
  let(:name) { "新しい猫" }
  let(:description) { "かわいい猫のタグ" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
  end

  it "updates a tag localization record" do
    described_class.update(tag:, locale:, name:, description:, user:)

    localization.reload
    expect(localization).to have_attributes(name:, description:)
  end

  it "returns localization without saving if nothing changed" do
    result =
      described_class.update(
        tag:,
        locale:,
        name: localization.name,
        description: localization.description,
        user:,
      )

    expect(result).to eq(localization)
  end

  it "raises not found if the tag is nil" do
    expect { described_class.update(tag: nil, locale:, name:, user:) }.to raise_error(
      Discourse::NotFound,
    )
  end

  it "raises not found if the localization is missing" do
    expect { described_class.update(tag:, locale: "nope", name:, user:) }.to raise_error(
      Discourse::NotFound,
    )
  end

  it "raises permission error if user is not in allowed groups" do
    group.remove(user)

    expect { described_class.update(tag:, locale:, name:, user:) }.to raise_error(
      Discourse::InvalidAccess,
    )
  end
end
