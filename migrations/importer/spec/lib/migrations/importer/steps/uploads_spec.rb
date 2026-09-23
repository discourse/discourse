# frozen_string_literal: true

# The step class needs Rails to load, so it is named as a string here.
RSpec.describe "Migrations::Importer::Steps::Uploads::InlineImport", :rails do
  subject(:inline_import) { Migrations::Importer::Steps::Uploads::InlineImport.new(step) }

  let(:uploads) { Migrations::Importer::Uploads }
  let(:settings) { { download_cache_path: @cache_path } }
  let(:step) do
    instance_double(
      Migrations::Importer::Steps::Uploads,
      intermediate_db: instance_double(Migrations::Database::Connection),
      reporter: instance_double(Migrations::Reporting::Reporter::StepHandle),
      config: {
        uploads: settings,
      },
    )
  end
  let(:pipeline) { instance_double(uploads::Pipeline, run: nil, interrupted?: false) }

  around do |example|
    Dir.mktmpdir do |dir|
      @cache_path = File.join(dir, "downloads")
      example.run
    end
  end

  before do
    allow(uploads::DatabasePool).to receive(:configure!)
    allow(uploads::Pipeline).to receive(:new).and_return(pipeline)
  end

  def pending_rows(*rows)
    allow(uploads::InlineWorkList).to receive(:rows).and_return(rows)
  end

  it "does nothing when there is no pending upload" do
    pending_rows

    inline_import.run

    expect(uploads::Pipeline).not_to have_received(:new)
  end

  it "requires root_paths when a pending upload is a file on disk" do
    pending_rows({ id: "a", filename: "a.png", path: "a.png" })

    expect { inline_import.run }.to raise_error(/root_paths/)
  end

  it "runs without root_paths when every pending upload has a url or data" do
    pending_rows({ id: "a", filename: "a.png", url: "https://example.com/a.png" })

    inline_import.run

    expect(pipeline).to have_received(:run)
  end

  it "configures the database pool before it builds the pipeline" do
    pending_rows({ id: "a", filename: "a.png", url: "https://example.com/a.png" })

    inline_import.run

    expect(uploads::DatabasePool).to have_received(:configure!).ordered
    expect(uploads::Pipeline).to have_received(:new).ordered
  end

  it "creates the download cache directory" do
    pending_rows({ id: "a", filename: "a.png", url: "https://example.com/a.png" })

    inline_import.run

    expect(File.directory?(@cache_path)).to be(true)
  end
end
