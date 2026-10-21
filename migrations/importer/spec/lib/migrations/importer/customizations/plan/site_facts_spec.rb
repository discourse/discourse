# frozen_string_literal: true

RSpec.describe Migrations::Importer::Customizations::Plan::SiteFacts, :rails do
  subject(:facts) { described_class.new(Migrations::Importer::Customizations::Matcher.build) }

  it "describes site settings" do
    expect(facts.site_setting("title")).to include(type: :string, hidden: false, secret: false)
    expect(facts.site_setting("github_client_secret")).to include(secret: true)
    expect(facts.site_setting("logo")).to include(type: :upload)
    expect(facts.site_setting("no_such_setting")).to be_nil
  end

  it "flags settings overridden by a global setting" do
    expect(facts.site_setting("title")).to include(global: false)
    expect(facts.site_setting("s3_region")).to include(global: true)

    allow(SiteSetting).to receive(:shadowed_settings).and_return(Set[:title])
    expect(facts.site_setting("title")).to include(global: true)
  end

  it "recognizes imported groups and categories" do
    imported = Fabricate(:group, name: "imported")
    GroupCustomField.create!(group_id: imported.id, name: "import_id", value: "7")
    local = Fabricate(:group, name: "local")
    parent = Fabricate(:category, slug: "parent")
    child = Fabricate(:category, slug: "child", parent_category: parent)

    expect(facts.group(imported.id)).to include(
      imported: true,
      match: {
        "import_id" => "7",
        "name" => "imported",
      },
    )
    expect(facts.group(local.id)).to include(imported: false)
    expect(facts.group(Group::AUTO_GROUPS[:admins])).to include(name: "admins", automatic: true)
    expect(facts.category(child.id)).to include(
      imported: false,
      match: {
        "slug_path" => "parent/child",
      },
    )
  end

  it "tells whether permalink targets still exist" do
    post = Fabricate(:post)
    trashed = Fabricate(:topic)
    trashed.trash!
    user = Fabricate(:user)
    tag = Fabricate(:tag)

    expect(facts.record_exists?(:topic, post.topic_id)).to eq(true)
    expect(facts.record_exists?(:post, post.id)).to eq(true)
    expect(facts.record_exists?(:user, user.id)).to eq(true)
    expect(facts.record_exists?(:tag, tag.id)).to eq(true)
    expect(facts.record_exists?(:topic, trashed.id)).to eq(false)
    expect(facts.record_exists?(:user, -9999)).to eq(false)
  end

  it "compares diff values with column defaults" do
    expect(facts.default_value?("groups", "primary_group", "f")).to eq(true)
    expect(facts.default_value?("groups", "primary_group", "t")).to eq(false)
    expect(facts.default_value?("categories", "uploaded_logo_id", nil)).to eq(true)
    expect(facts.default_value?("groups", "bio_raw", "")).to eq(true)
  end
end
