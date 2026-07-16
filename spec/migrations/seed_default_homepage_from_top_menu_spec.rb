# frozen_string_literal: true

require Rails.root.join("db/migrate/20260706122824_seed_default_homepage_from_top_menu.rb")

RSpec.describe SeedDefaultHomepageFromTopMenu do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    Migration::Helpers.stubs(:existing_site?).returns(true)
  end

  after do
    ActiveRecord::Migration.verbose = @original_verbose
    DB.exec("DELETE FROM site_settings WHERE name IN ('top_menu', 'default_homepage')")
  end

  def set_top_menu(value)
    DB.exec(<<~SQL, value: value)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('top_menu', 8, :value, NOW(), NOW())
      ON CONFLICT (name) DO UPDATE SET value = :value
    SQL
  end

  def default_homepage_value
    DB.query_single("SELECT value FROM site_settings WHERE name = 'default_homepage'").first
  end

  it "seeds default_homepage from a reordered top_menu" do
    set_top_menu("categories|latest|new")
    described_class.new.up
    expect(default_homepage_value).to eq("categories")
  end

  it "ignores the category-exclusion suffix on the first item" do
    set_top_menu("hot,-2|latest")
    described_class.new.up
    expect(default_homepage_value).to eq("hot")
  end

  it "does not seed when latest is already first" do
    set_top_menu("latest|new|categories")
    described_class.new.up
    expect(default_homepage_value).to be_nil
  end

  it "does not seed on a fresh install (no top_menu row)" do
    described_class.new.up
    expect(default_homepage_value).to be_nil
  end

  it "does not seed on a brand new site even if top_menu was customized" do
    Migration::Helpers.stubs(:existing_site?).returns(false)
    set_top_menu("categories|latest")
    described_class.new.up
    expect(default_homepage_value).to be_nil
  end

  it "does not overwrite an existing default_homepage" do
    set_top_menu("categories|latest")
    DB.exec(<<~SQL)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('default_homepage', 7, 'hot', NOW(), NOW())
    SQL
    described_class.new.up
    expect(default_homepage_value).to eq("hot")
  end
end
