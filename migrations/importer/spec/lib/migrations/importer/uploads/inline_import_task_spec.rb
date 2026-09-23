# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::InlineImportTask do
  # The upload service is a double, because creating uploads needs Rails. Each
  # row goes through `process` (a worker) and `write` (the writer), and the
  # writer stores it on a real SQLite connection.
  subject(:task) do
    described_class
      .new(work_list: [row], intermediate_db: db, upload_service: service)
      .tap { |t| t.reporter = reporter }
  end

  include_context "with mapped intermediate db"

  let(:row) { { id: "a", filename: "a.png", resolved_user_id: 5 } }
  let(:enums) { Migrations::Database::FilesDB::Enums }
  let(:service) { instance_double(Migrations::Importer::Uploads::UploadCreationService) }
  let(:reporter) { instance_double(Migrations::Reporting::Reporter::StepHandle, notice: nil) }

  def service_returns(status:, upload_id: nil, markdown: nil, skip_details: nil)
    result =
      Migrations::Importer::Uploads::UploadCreationService::Result.new(
        source_id: row[:id],
        status:,
        upload: upload_id && Data.define(:id).new(upload_id),
        markdown:,
        skip_details:,
      )
    allow(service).to receive(:create).with(row, user_id: row[:resolved_user_id]).and_return(result)
  end

  # Runs the row the way the pipeline does and returns the write outcome.
  def import_row
    entry = task.process(row, nil)
    outcome = task.write(entry)
    task.after_run
    outcome
  end

  def mapped_ids
    db.query("SELECT original_id, type, discourse_id FROM mapped.ids")
  end

  def upload_markdown
    db.query("SELECT original_id, markdown FROM mapped.upload_markdown")
  end

  it "emits every row of the work list" do
    emitted = []
    task.produce(emit_work: ->(work) { emitted << work }, emit_result: ->(_) {})

    expect(emitted).to eq([row])
  end

  it "asks the upload service's store whether it is external" do
    allow(service).to receive(:discourse_store).and_return(
      instance_double("FileStore::BaseStore", external?: true),
    )

    expect(task.store_external?).to be(true)
  end

  it "records the mapping and the markdown of an upload owned by the mapped user" do
    service_returns(status: enums::UploadResultStatus::OK, upload_id: 71, markdown: "![](x)")

    expect(import_row).to eq(:ok)
    expect(mapped_ids).to contain_exactly(
      { original_id: "a", type: Migrations::Importer::MappingType::UPLOADS, discourse_id: 71 },
    )
    expect(upload_markdown).to contain_exactly({ original_id: "a", markdown: "![](x)" })
  end

  it "drops a row the service returned nil for" do
    allow(service).to receive(:create).and_return(nil)

    expect(task.process(row, nil)).to be_nil
  end

  it "leaves a missing source file unmapped and reports it" do
    service_returns(status: enums::UploadResultStatus::SKIPPED)

    expect(import_row).to eq(:skip)
    expect(reporter).to have_received(:notice).with(/upload a \(a\.png\)/)
    expect(mapped_ids).to be_empty
    expect(upload_markdown).to be_empty
  end

  it "leaves a failed upload unmapped and reports its error" do
    service_returns(status: enums::UploadResultStatus::ERROR, skip_details: "boom")

    expect(import_row).to eq(:error)
    expect(reporter).to have_received(:notice).with(/boom/)
    expect(mapped_ids).to be_empty
  end

  it "reports a failed insert as an error instead of raising" do
    service_returns(status: enums::UploadResultStatus::OK, upload_id: 71, markdown: "![](x)")
    allow(db).to receive(:insert).and_raise(StandardError, "disk full")

    expect(task.write(task.process(row, nil))).to eq(:error)
    expect(reporter).to have_received(:notice).with(/record upload a: disk full/)
  end
end
