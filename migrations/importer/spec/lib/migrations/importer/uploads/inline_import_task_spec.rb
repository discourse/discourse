# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::InlineImportTask do
  # The upload service is a double, because creating uploads needs Rails. These
  # tests cover how a worker result is built and how the writer stores it in
  # `mapped.ids` and `mapped.upload_markdown` on a real SQLite connection.
  subject(:task) do
    described_class
      .new(
        work_list: [{ id: "a", resolved_user_id: 5 }],
        intermediate_db: db,
        upload_service: service,
      )
      .tap { |t| t.reporter = reporter }
  end

  around do |example|
    Dir.mktmpdir do |dir|
      intermediate_path = File.join(dir, "intermediate.db")
      mappings_path = File.join(dir, "mappings.db")

      Migrations::Database.migrate(
        intermediate_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )
      Migrations::Database.migrate(
        mappings_path,
        migrations_path: Migrations::Database::MAPPINGS_DB_SCHEMA_PATH,
      )

      @db = Migrations::Database.connect(intermediate_path)
      @db.execute("ATTACH DATABASE ? AS mapped", mappings_path)
      example.run
    ensure
      @db&.close
    end
  end

  let(:db) { @db }
  let(:enums) { Migrations::Database::FilesDB::Enums }
  let(:service) { instance_double(Migrations::Importer::Uploads::UploadCreationService) }
  let(:reporter) { instance_double(Migrations::Reporting::Reporter::StepHandle, notice: nil) }

  def ok_result(source_id, upload_id, markdown)
    Migrations::Importer::Uploads::UploadCreationService::Result.new(
      source_id:,
      status: enums::UploadResultStatus::OK,
      upload: Data.define(:id).new(upload_id),
      markdown:,
      skip_reason: nil,
      skip_details: nil,
      download: nil,
    )
  end

  def mapped_ids
    db.query("SELECT original_id, type, discourse_id FROM mapped.ids")
  end

  def upload_markdown
    db.query("SELECT original_id, markdown FROM mapped.upload_markdown")
  end

  describe "#produce" do
    it "emits every materialized work row" do
      emitted = []
      task.produce(emit_work: ->(row) { emitted << row }, emit_result: ->(_) {})

      expect(emitted).to eq([{ id: "a", resolved_user_id: 5 }])
    end
  end

  describe "#store_external?" do
    it "asks the upload service's store" do
      allow(service).to receive(:discourse_store).and_return(
        instance_double("FileStore::BaseStore", external?: true),
      )

      expect(task.store_external?).to be(true)
    end
  end

  describe "#process" do
    it "shapes a plain entry from the service result, owned by the mapped user" do
      allow(service).to receive(:create).with(
        { id: "a", resolved_user_id: 5 },
        user_id: 5,
      ).and_return(ok_result("a", 71, "![](x)"))

      entry = task.process({ id: "a", resolved_user_id: 5 }, nil)

      expect(entry).to include(
        original_id: "a",
        status: enums::UploadResultStatus::OK,
        discourse_id: 71,
        markdown: "![](x)",
      )
    end

    it "drops a row the service returned nil for" do
      allow(service).to receive(:create).and_return(nil)

      expect(task.process({ id: "a", resolved_user_id: 5 }, nil)).to be_nil
    end
  end

  describe "#write" do
    it "records the mapping and the markdown for a created upload" do
      entry = {
        original_id: "a",
        status: enums::UploadResultStatus::OK,
        discourse_id: 71,
        markdown: "![](x)",
        skip_details: nil,
        download: nil,
      }

      expect(task.write(entry)).to eq(:ok)
      task.after_run

      expect(mapped_ids).to contain_exactly(
        { original_id: "a", type: Migrations::Importer::MappingType::UPLOADS, discourse_id: 71 },
      )
      expect(upload_markdown).to contain_exactly({ original_id: "a", markdown: "![](x)" })
    end

    it "leaves a missing source file unmapped and reports it" do
      entry = {
        original_id: "a",
        filename: "a.png",
        status: enums::UploadResultStatus::SKIPPED,
        skip_details: nil,
        download: nil,
      }

      expect(task.write(entry)).to eq(:skip)
      task.after_run

      expect(reporter).to have_received(:notice).with(/upload a \(a\.png\)/)
      expect(mapped_ids).to be_empty
      expect(upload_markdown).to be_empty
    end

    it "reports a failed insert as an error instead of raising" do
      allow(db).to receive(:insert).and_raise(StandardError, "disk full")
      entry = {
        original_id: "a",
        status: enums::UploadResultStatus::OK,
        discourse_id: 71,
        markdown: "![](x)",
        skip_details: nil,
        download: nil,
      }

      expect(task.write(entry)).to eq(:error)
      expect(reporter).to have_received(:notice).with(/record upload a: disk full/)
    end

    it "notices and counts an error, without mapping it" do
      entry = {
        original_id: "a",
        status: enums::UploadResultStatus::ERROR,
        skip_details: "boom",
        download: nil,
      }

      expect(task.write(entry)).to eq(:error)
      task.after_run

      expect(reporter).to have_received(:notice)
      expect(mapped_ids).to be_empty
    end
  end
end
