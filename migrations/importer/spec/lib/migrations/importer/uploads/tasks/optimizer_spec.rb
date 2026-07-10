# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::Tasks::Optimizer do
  # The loader methods under test read straight from a real IntermediateDB, so we
  # build the task with `allocate` (skipping the Rails-touching constructor) and
  # hand it a migrated SQLite fixture. No Rails needed.
  subject(:optimizer) do
    described_class.allocate.tap do |task|
      task.instance_variable_set(:@intermediate_db, intermediate_db)
    end
  end

  let(:intermediate_db) { @intermediate_db }

  around do |example|
    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "intermediate.db")
      Migrations::Database.migrate(
        db_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )
      @intermediate_db = Migrations::Database.connect(db_path)
      example.run
    ensure
      @intermediate_db&.close
    end
  end

  describe "#load_post_upload_ids" do
    it "collects the distinct, non-null upload ids from post_uploads" do
      insert_post_upload(placeholder: "a", post_id: 1, upload_id: "u1")
      insert_post_upload(placeholder: "b", post_id: 1, upload_id: "u1")
      insert_post_upload(placeholder: "c", post_id: 2, upload_id: "u2")
      insert_post_upload(placeholder: "d", post_id: 3, upload_id: nil)

      expect(optimizer.send(:load_post_upload_ids)).to contain_exactly("u1", "u2")
    end

    it "returns an empty set when there are no post uploads" do
      expect(optimizer.send(:load_post_upload_ids)).to be_empty
    end
  end

  describe "#load_avatar_upload_ids" do
    it "collects the non-null uploaded_avatar_id values from users" do
      insert_user(original_id: 1, uploaded_avatar_id: "a1")
      insert_user(original_id: 2, uploaded_avatar_id: "a2")
      insert_user(original_id: 3, uploaded_avatar_id: nil)

      expect(optimizer.send(:load_avatar_upload_ids)).to contain_exactly("a1", "a2")
    end

    it "returns an empty set when no user has an avatar" do
      insert_user(original_id: 1, uploaded_avatar_id: nil)

      expect(optimizer.send(:load_avatar_upload_ids)).to be_empty
    end
  end

  def insert_post_upload(placeholder:, post_id:, upload_id:)
    intermediate_db.execute(
      "INSERT INTO post_uploads (placeholder, post_id, upload_id) VALUES (?, ?, ?)",
      placeholder,
      post_id,
      upload_id,
    )
  end

  def insert_user(original_id:, uploaded_avatar_id:)
    intermediate_db.execute(
      "INSERT INTO users (original_id, created_at, trust_level, username, uploaded_avatar_id) " \
        "VALUES (?, ?, ?, ?, ?)",
      original_id,
      "2026-01-01T00:00:00Z",
      0,
      "user#{original_id}",
      uploaded_avatar_id,
    )
  end
end
