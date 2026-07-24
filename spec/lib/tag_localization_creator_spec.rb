# frozen_string_literal: true

describe TagLocalizationCreator do
  fab!(:user)
  fab!(:tag)
  fab!(:group)

  let(:locale) { "ja" }
  let(:name) { "猫タグ" }
  let(:description) { "猫についてのタグです" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
  end

  it "creates a tag localization record" do
    localization = described_class.create(tag:, locale:, name:, description:, user:)

    expect(TagLocalization.find(localization.id)).to have_attributes(
      tag_id: tag.id,
      locale:,
      name:,
      description:,
    )
  end

  it "sanitizes unsafe description HTML", :aggregate_failures do
    unsafe_description =
      '<script>alert("xss")</script><a href="https://example.com" onclick="alert(1)">link</a>'
    sanitized_description = Fabricate(:tag, description: unsafe_description).description

    localization =
      described_class.create(tag:, locale:, name:, description: unsafe_description, user:)

    expect(localization.description).to eq(sanitized_description)
    expect(localization.description).not_to match(/<script|onclick/i)
  end

  it "creates localization without description" do
    localization = described_class.create(tag:, locale:, name:, user:)

    expect(TagLocalization.find(localization.id)).to have_attributes(
      tag_id: tag.id,
      locale:,
      name:,
      description: nil,
    )
  end

  it "raises not found if the tag is nil" do
    expect { described_class.create(tag: nil, locale:, name:, user:) }.to raise_error(
      Discourse::NotFound,
    )
  end

  it "raises permission error if user is not in allowed groups" do
    group.remove(user)

    expect { described_class.create(tag:, locale:, name:, user:) }.to raise_error(
      Discourse::InvalidAccess,
    )
  end
end
