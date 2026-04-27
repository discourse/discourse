# frozen_string_literal: true

require Rails.root.join("db/migrate/20260422062338_move_web_artifacts_to_core.rb")

RSpec.describe MoveWebArtifactsToCore do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    # Reset state: undo anything the migration would have done in a previous run
    DB.exec "DROP TRIGGER IF EXISTS ai_artifacts_readonly ON ai_artifacts"
    DB.exec "DROP TRIGGER IF EXISTS ai_artifact_versions_readonly ON ai_artifact_versions"
    DB.exec "DROP TRIGGER IF EXISTS ai_artifact_key_values_readonly ON ai_artifact_key_values"
    DB.exec "TRUNCATE web_artifact_key_values, web_artifact_versions, web_artifacts RESTART IDENTITY"
    DB.exec "TRUNCATE ai_artifact_key_values, ai_artifact_versions, ai_artifacts RESTART IDENTITY"

    # Simulate pre-migration setting names
    DB.exec <<~SQL
      UPDATE site_settings SET name = 'ai_artifact_security' WHERE name = 'web_artifact_security';
      UPDATE site_settings SET name = 'ai_artifact_kv_value_max_length' WHERE name = 'web_artifact_kv_value_max_length';
      UPDATE site_settings SET name = 'ai_artifact_max_keys_per_user_per_artifact' WHERE name = 'web_artifact_max_keys_per_user_per_artifact';
    SQL
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def insert_ai_artifact(id:, user_id:, post_id:, name:, html: "<p>hi</p>")
    DB.exec(<<~SQL, id: id, user_id: user_id, post_id: post_id, name: name, html: html)
      INSERT INTO ai_artifacts (id, user_id, post_id, name, html, created_at, updated_at)
      VALUES (:id, :user_id, :post_id, :name, :html, NOW(), NOW())
    SQL
  end

  it "copies data from ai_artifacts to web_artifacts" do
    insert_ai_artifact(id: 101, user_id: 1, post_id: 42, name: "First")
    insert_ai_artifact(id: 102, user_id: 2, post_id: 43, name: "Second", html: "<b>x</b>")

    described_class.new.up

    rows = DB.query("SELECT id, user_id, post_id, name, html FROM web_artifacts ORDER BY id")
    expect(rows.map(&:id)).to eq([101, 102])
    expect(rows[0].name).to eq("First")
    expect(rows[1].html).to eq("<b>x</b>")
  end

  it "copies versions and key-values with the renamed foreign key column" do
    insert_ai_artifact(id: 201, user_id: 1, post_id: 42, name: "A")

    DB.exec(<<~SQL)
      INSERT INTO ai_artifact_versions (id, ai_artifact_id, version_number, html, created_at, updated_at)
      VALUES (11, 201, 1, '<p>v1</p>', NOW(), NOW());

      INSERT INTO ai_artifact_key_values (id, ai_artifact_id, user_id, key, value, public, created_at, updated_at)
      VALUES (22, 201, 1, 'k', 'v', false, NOW(), NOW());
    SQL

    described_class.new.up

    version = DB.query("SELECT web_artifact_id, version_number FROM web_artifact_versions").first
    expect(version.web_artifact_id).to eq(201)
    expect(version.version_number).to eq(1)

    kv = DB.query("SELECT web_artifact_id, key, value FROM web_artifact_key_values").first
    expect(kv.web_artifact_id).to eq(201)
    expect(kv.key).to eq("k")
  end

  it "syncs sequences so new inserts don't collide with copied ids" do
    insert_ai_artifact(id: 5000, user_id: 1, post_id: 42, name: "High")

    described_class.new.up

    next_id =
      DB.query_single(
        "INSERT INTO web_artifacts (user_id, name, html, created_at, updated_at) VALUES (1, 'next', '<p/>', NOW(), NOW()) RETURNING id",
      ).first

    expect(next_id).to be > 5000
  end

  it "marks the old tables readonly" do
    insert_ai_artifact(id: 301, user_id: 1, post_id: 42, name: "A")

    described_class.new.up

    expect {
      DB.exec(
        "INSERT INTO ai_artifacts (user_id, name, html, created_at, updated_at) VALUES (1, 'new', '<p/>', NOW(), NOW())",
      )
    }.to raise_error(PG::RaiseException, /ai_artifacts is read only/)
  end

  it "renames site settings from ai_artifact_* to web_artifact_*" do
    DB.exec <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('ai_artifact_security', 7, 'strict', NOW(), NOW())
      ON CONFLICT (name) DO UPDATE SET value = EXCLUDED.value;
    SQL

    described_class.new.up

    value =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'web_artifact_security'").first
    expect(value).to eq("strict")
    expect(
      DB.query_single("SELECT 1 FROM site_settings WHERE name = 'ai_artifact_security'"),
    ).to be_empty
  end

  it "deletes orphaned ai/manage_artifacts API key scopes" do
    api_key = ApiKey.create!
    DB.exec(<<~SQL, api_key_id: api_key.id)
      INSERT INTO api_key_scopes (api_key_id, resource, action, created_at, updated_at)
      VALUES (:api_key_id, 'ai', 'manage_artifacts', NOW(), NOW())
    SQL

    described_class.new.up

    expect(
      DB.query_single(
        "SELECT 1 FROM api_key_scopes WHERE resource = 'ai' AND action = 'manage_artifacts'",
      ),
    ).to be_empty
  end
end
