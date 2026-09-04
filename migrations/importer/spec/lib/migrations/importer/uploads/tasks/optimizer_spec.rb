# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::Tasks::Optimizer, :rails do
  subject(:optimizer) do
    described_class.new({ files_db:, intermediate_db: }, {}).tap { |task| task.reporter = reporter }
  end

  let(:reporter) { instance_double(Migrations::Reporting::Reporter::StepHandle, notice: nil) }
  let(:intermediate_db) { @intermediate_db }
  let(:files_db) { @files_db }

  around do |example|
    Dir.mktmpdir do |dir|
      intermediate_db_path = File.join(dir, "intermediate.db")
      files_db_path = File.join(dir, "files.db")
      Migrations::Database.migrate(
        intermediate_db_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )
      Migrations::Database.migrate(
        files_db_path,
        migrations_path: Migrations::Database::FILES_DB_SCHEMA_PATH,
      )
      @intermediate_db = Migrations::Database.connect(intermediate_db_path)
      @files_db = Migrations::Database.connect(files_db_path)
      example.run
    ensure
      @intermediate_db&.close
      @files_db&.close
    end
  end

  # The whole enqueue path — the tracking sets loaded in `before_run` deciding
  # what `produce` hands to the workers — against real, migrated databases. An
  # earlier version of the set loaders queried IntermediateDB columns that don't
  # exist, so every row was "unreferenced" and --optimize silently optimized
  # nothing; a query that drifts from the schema fails here.
  describe "enqueueing" do
    it "enqueues post images and avatars and skips the rest" do
      insert_uploaded_image(source_id: "s-post", upload_id: 1)
      insert_uploaded_image(source_id: "s-avatar", upload_id: 2)
      insert_uploaded_image(source_id: "s-unreferenced", upload_id: 3)
      insert_uploaded_image(source_id: "s-optimized", upload_id: 4)
      insert_result(source_id: "s-attachment", upload_id: 5, markdown: "[file](upload://e)")
      insert_optimized_image(upload_id: 4)

      insert_embed_upload(placeholder: "a", post_id: 1, upload_id: "s-post")
      insert_embed_upload(placeholder: "b", post_id: 1, upload_id: "s-post")
      insert_embed_upload(placeholder: "c", post_id: 2, upload_id: nil)
      insert_user(original_id: 1, uploaded_avatar_id: "s-avatar")
      insert_user(original_id: 2, uploaded_avatar_id: nil)

      work, skipped = run_enqueue

      expect(work.map { |row| row.values_at(:source_id, :type) }).to contain_exactly(
        %w[s-post post],
        %w[s-avatar avatar],
      )
      expect(skipped.map { |result| result[:id] }).to contain_exactly(3, 4, 5)
      expect(optimizer.max_count).to eq(5)
    end

    it "enqueues nothing when no post or avatar references an upload" do
      insert_uploaded_image(source_id: "s1", upload_id: 1)

      work, skipped = run_enqueue

      expect(work).to be_empty
      expect(skipped.map { |result| result[:id] }).to contain_exactly(1)
    end
  end

  def run_enqueue
    optimizer.before_run

    work = []
    skipped = []
    optimizer.produce(
      emit_work: ->(row) { work << row },
      emit_result: ->(result) { skipped << result },
    )
    [work, skipped]
  end

  def insert_uploaded_image(source_id:, upload_id:)
    insert_result(source_id:, upload_id:, markdown: "![image](upload://#{source_id})")
  end

  def insert_result(source_id:, upload_id:, markdown:)
    files_db.execute(
      "INSERT INTO uploads (id, sha1, url, filesize, original_filename) VALUES (?, ?, ?, ?, ?)",
      upload_id,
      "sha1-#{upload_id}",
      "//uploads/#{upload_id}.png",
      100,
      "#{upload_id}.png",
    )
    files_db.execute(
      "INSERT INTO upload_results (id, status, markdown, upload_id) VALUES (?, 'ok', ?, ?)",
      source_id,
      markdown,
      upload_id,
    )
  end

  def insert_optimized_image(upload_id:)
    files_db.execute(
      "INSERT INTO optimized_images (upload_id, sha1, extension, width, height, url) " \
        "VALUES (?, 'abc', 'png', 100, 100, '//x.png')",
      upload_id,
    )
  end

  def insert_embed_upload(placeholder:, post_id:, upload_id:)
    intermediate_db.execute(
      "INSERT INTO embed_uploads (placeholder, owner_id, owner_type, upload_id) VALUES (?, ?, ?, ?)",
      placeholder,
      post_id,
      Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
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
