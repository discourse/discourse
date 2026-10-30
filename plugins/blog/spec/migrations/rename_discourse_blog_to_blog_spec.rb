# frozen_string_literal: true

require Rails.root.join("plugins/blog/db/migrate/20261028093146_rename_discourse_blog_to_blog.rb")
require Rails.root.join(
          "plugins/blog/db/post_migrate/20261028093149_finish_rename_discourse_blog_to_blog.rb",
        )

RSpec.describe RenameDiscourseBlogToBlog do
  fab!(:upload)

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    # The test schema already uses the new names, so recreate the old one.
    described_class::RENAMED_TABLES.each do |old_name, new_name|
      DB
        .query_single(<<~SQL, new_name.to_s)
          SELECT i.relname
          FROM pg_index x
          JOIN pg_class i ON i.oid = x.indexrelid
          WHERE x.indrelid = ?::regclass
        SQL
        .each do |name|
          DB.exec("ALTER INDEX #{name} RENAME TO #{name.sub(new_name.to_s, old_name.to_s)}")
        end
      DB.exec("ALTER SEQUENCE #{new_name}_id_seq RENAME TO #{old_name}_id_seq")
      DB.exec("ALTER TABLE #{new_name} RENAME TO #{old_name}")
    end
  end

  after do
    ActiveRecord::Migration.verbose = @original_verbose
    Migration::SafeMigrate.disable!
  end

  def relation_names(pattern, kind)
    DB.query_single("SELECT relname FROM pg_class WHERE relname ~ ? AND relkind = ?", pattern, kind)
  end

  def insert_setting(name, value, data_type: SiteSettings::TypeSupervisor.types[:string])
    DB.exec(<<~SQL, name:, value:, data_type:)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES (:name, :data_type, :value, NOW(), NOW())
    SQL
  end

  def setting_value(name)
    DB.query_single("SELECT value FROM site_settings WHERE name = ?", name).first
  end

  def insert_reference(target_type, target_id)
    DB.exec(<<~SQL, upload_id: upload.id, target_type:, target_id:)
      INSERT INTO upload_references (upload_id, target_type, target_id, created_at, updated_at)
      VALUES (:upload_id, :target_type, :target_id, NOW(), NOW())
    SQL
  end

  def reference_types
    DB.query_single("SELECT target_type FROM upload_references WHERE upload_id = ?", upload.id)
  end

  it "renames the tables and their objects, keeping views under the old names until after deploy" do
    old_names = described_class::RENAMED_TABLES.keys.map(&:to_s)
    new_names = described_class::RENAMED_TABLES.values.map(&:to_s)

    described_class.new.up

    expect(relation_names("^blog_", "r")).to match_array(new_names)
    expect(relation_names("^discourse_blog_", "v")).to match_array(old_names)
    expect(relation_names("discourse_blog", "i")).to be_empty
    expect(relation_names("discourse_blog", "S")).to be_empty
    expect(relation_names("^idx_blog_publications_scheduled_at$", "i")).to be_present
    expect(DB.query_single("SELECT COUNT(*) FROM discourse_blog_publications")).to eq([0])

    FinishRenameDiscourseBlogToBlog.new.up
    described_class.new.up

    expect(relation_names("^discourse_blog_", "v")).to be_empty
    expect(relation_names("^blog_", "r")).to match_array(new_names)
  end

  it "renames the settings without overwriting values already saved under the new names" do
    insert_setting("discourse_blog_url", "https://blog.example.com")
    insert_setting("discourse_blog_title", "Old title")
    insert_setting("blog_title", "New title")

    described_class.new.up

    expect(setting_value("blog_url")).to eq("https://blog.example.com")
    expect(setting_value("discourse_blog_url")).to be_nil
    expect(setting_value("blog_title")).to eq("New title")
  end

  it "renames stored class names on upload references, including ones written after deploy" do
    insert_reference("DiscourseBlog::Review", 1)

    described_class.new.up

    expect(reference_types).to contain_exactly("Blog::Review")

    insert_reference("DiscourseBlog::Revision", 2)
    insert_reference("DiscourseBlog::Review", 1)

    FinishRenameDiscourseBlogToBlog.new.up

    expect(reference_types).to contain_exactly("Blog::Review", "Blog::Revision")
  end
end
