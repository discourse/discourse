# frozen_string_literal: true

describe TagLocalizationDestroyer do
  fab!(:user)
  fab!(:tag)
  fab!(:group)

  let(:locale) { "ja" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
  end

  it "destroys a tag localization record" do
    localization = Fabricate(:tag_localization, tag: tag, locale:)

    expect { described_class.destroy(tag:, locale:, acting_user: user) }.to change {
      TagLocalization.count
    }.by(-1)
  end

  it "raises not found if the tag is nil" do
    expect { described_class.destroy(tag: nil, locale:, acting_user: user) }.to raise_error(
      Discourse::NotFound,
    )
  end

  it "raises not found if the localization is missing" do
    expect { described_class.destroy(tag:, locale: "nope", acting_user: user) }.to raise_error(
      Discourse::NotFound,
    )
  end

  it "raises permission error if user is not in allowed groups" do
    Fabricate(:tag_localization, tag: tag, locale:)
    group.remove(user)

    expect { described_class.destroy(tag:, locale:, acting_user: user) }.to raise_error(
      Discourse::InvalidAccess,
    )
  end
end
