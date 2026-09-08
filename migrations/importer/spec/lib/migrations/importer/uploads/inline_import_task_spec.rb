# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::InlineImportTask do
  # The upload-creation seam is stubbed (that is the Rails-backed part); what is
  # exercised here is the writer path: shaping a worker result and landing it in
  # `mapped.ids` + `mapped.upload_markdown` on a real SQLite connection.
  service_class = Migrations::Importer::Uploads::UploadCreationService
  status = service_class::Status

  subject(:task) do
    described_class
      .new(
        work_list: [{ id: "a", resolved_user_id: 5 }],
        intermediate_db: db,
        upload_service: service,
        downloads_store:,
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
  let(:service) { instance_double(service_class) }
  let(:reporter) { instance_double(Migrations::Reporting::Reporter::StepHandle, notice: nil) }
  let(:downloads_store) { {} }

  def ok_result(source_id, upload_id, markdown)
    Migrations::Importer::Uploads::UploadCreationService::Result.new(
      source_id:,
      status: Migrations::Importer::Uploads::UploadCreationService::Status::OK,
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

  describe "#process" do
    it "shapes a plain entry from the service result, owned by the mapped user" do
      allow(service).to receive(:create).with(
        { id: "a", resolved_user_id: 5 },
        user_id: 5,
      ).and_return(ok_result("a", 71, "![](x)"))

      entry = task.process({ id: "a", resolved_user_id: 5 }, nil)

      expect(entry).to include(
        original_id: "a",
        status: status::OK,
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
        status: status::OK,
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

    it "leaves a skipped source unmapped so it surfaces downstream" do
      entry = { original_id: "a", status: status::SKIPPED, skip_details: nil, download: nil }

      expect(task.write(entry)).to eq(:skip)
      task.after_run

      expect(mapped_ids).to be_empty
      expect(upload_markdown).to be_empty
    end

    it "notices and counts an error, without mapping it" do
      entry = { original_id: "a", status: status::ERROR, skip_details: "boom", download: nil }

      expect(task.write(entry)).to eq(:error)
      task.after_run

      expect(reporter).to have_received(:notice)
      expect(mapped_ids).to be_empty
    end

    it "keeps the download filename cache current for a fresh download" do
      entry = {
        original_id: "a",
        status: status::SKIPPED,
        skip_details: nil,
        download: {
          id: "dl-1",
          original_filename: "a.png",
        },
      }

      task.write(entry)

      expect(downloads_store).to eq({ "dl-1" => "a.png" })
    end
  end
end
