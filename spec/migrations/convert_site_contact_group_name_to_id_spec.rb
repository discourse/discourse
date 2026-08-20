# frozen_string_literal: true

require Rails.root.join("db/migrate/20260820092502_convert_site_contact_group_name_to_id.rb")

RSpec.describe ConvertSiteContactGroupNameToId do
  subject(:migrate) { described_class.new.up }

  # The site settings provider is swapped for an in-memory one in specs, so
  # `SiteSetting.site_contact_group_name=` never reaches the table.
  def store(value)
    DB.exec(<<~SQL, value: value)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('site_contact_group_name', 19, :value, NOW(), NOW())
      ON CONFLICT (name) DO UPDATE SET value = :value
    SQL
  end

  def stored
    DB.query_single("SELECT value FROM site_settings WHERE name = 'site_contact_group_name'").first
  end

  before do
    @verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @verbose }

  it "does nothing when the setting was never overridden" do
    expect { migrate }.not_to raise_error
    expect(stored).to eq(nil)
  end

  it "leaves a blank value alone" do
    store("")
    migrate
    expect(stored).to eq("")
  end

  it "converts a group name to its id" do
    group = Fabricate(:group, name: "support")
    store("support")

    migrate

    expect(stored).to eq(group.id.to_s)
  end

  it "converts a group name that differs in case or has stray whitespace" do
    group = Fabricate(:group, name: "support")
    store("  SUPPORT  ")

    migrate

    expect(stored).to eq(group.id.to_s)
  end

  it "leaves a value that is already an id alone, however many times it runs" do
    group = Fabricate(:group)
    store(group.id.to_s)

    migrate
    migrate

    expect(stored).to eq(group.id.to_s)
  end

  it "leaves a name that matches no group alone" do
    store("longgone")
    migrate
    expect(stored).to eq("longgone")
  end

  it "does not guess when a group is named after another group's id" do
    # The id is pinned so that the name below clears the three character minimum.
    other = Fabricate(:group, id: 12_345)
    Fabricate(:group, name: other.id.to_s)
    store(other.id.to_s)

    migrate

    expect(stored).to eq(other.id.to_s)
  end
end
