# frozen_string_literal: true

require Rails.root.join(
          "plugins/blog/db/migrate/20261123103548_copy_legacy_settings_to_default_blog.rb",
        )

RSpec.describe CopyLegacySettingsToDefaultBlog do
  fab!(:category)

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    DB.exec("DELETE FROM blog_instances")
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def store_setting(name, value)
    DB.exec(<<~SQL, name:, value: value.to_s)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES (:name, 1, :value, NOW(), NOW())
    SQL
  end

  def insert_placeholder
    DB.exec(<<~SQL)
      INSERT INTO blog_instances (name, slug, is_default, created_at, updated_at)
      VALUES ('', 'blog', TRUE, NOW(), NOW())
    SQL
  end

  it "creates the default blog from a site's saved settings and theme" do
    store_setting("blog_title", "Field notes")
    store_setting("blog_url", "https://blog.example.com")
    store_setting("blog_category", category.id)
    store_setting("blog_posts_per_page", 5)
    PluginStore.set("discourse-blog-themes", "active", { "id" => "ledger", "preset" => true })

    described_class.new.up

    expect(Blog::Instance.sole).to have_attributes(
      name: "Field notes",
      slug: "blog",
      is_default: true,
      url: "https://blog.example.com",
      category_id: category.id,
      posts_per_page: 5,
      path_format: "/{slug}",
      description: "Ideas, stories, and conversations.",
      active_theme: {
        "id" => "ledger",
        "preset" => true,
      },
    )
  end

  it "fills in the placeholder an earlier migration inserts" do
    insert_placeholder
    store_setting("blog_title", "Field notes")

    described_class.new.up

    expect(Blog::Instance.sole.name).to eq("Field notes")
  end

  it "names the placeholder on a site that saved no settings" do
    insert_placeholder

    described_class.new.up

    expect(Blog::Instance.sole).to have_attributes(name: "The blog", url: nil, category_id: nil)
  end

  it "leaves a default blog that already has a name alone" do
    Blog::Instance.create!(name: "Kept", slug: "blog", is_default: true)
    store_setting("blog_title", "Field notes")

    expect { described_class.new.up }.not_to change { Blog::Instance.sole.attributes }
  end

  it "adds no row to a site that never configured a blog" do
    described_class.new.up

    expect(Blog::Instance.count).to eq(0)
  end
end
