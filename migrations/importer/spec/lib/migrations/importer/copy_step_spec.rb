# frozen_string_literal: true

# The class body reads a Rails constant, so it is only named inside the lazily
# evaluated blocks below - the file is loaded even when `:rails` is excluded.
RSpec.describe "Migrations::Importer::CopyStep", :rails do
  include_context "with importer databases"

  let(:discourse_db) { instance_double(Migrations::Importer::DiscourseDB) }
  let(:shared_data) { instance_double(Migrations::Importer::SharedData) }
  let(:progress) { instance_double(Migrations::Reporting::Reporter::Progress, update: nil) }
  let(:reporter) { instance_double(Migrations::Reporting::Reporter::StepHandle) }
  let(:trace) { [] }
  let(:copied_names) { @copied_rows.map { |row| row[:name] } }

  # Records what the step sees and in which order, so an example can check that
  # a batch arrives before its rows are transformed.
  def build_step_class(size)
    Class.new(Migrations::Importer::CopyStep) do
      table_name "tags"
      column_names %i[name]
      batch_size size if size
      total_rows_query "SELECT COUNT(*) FROM tags"
      rows_query "SELECT original_id, name FROM tags ORDER BY original_id"

      attr_accessor :trace

      private

      def before_batch(rows)
        @trace << [:batch, rows.map { |row| row[:name] }]
      end

      def transform_row(row)
        @trace << [:row, row[:name]]
        return nil if row[:name] == "skipped"
        super
      end
    end
  end

  def build_step(batch_size: nil)
    step = build_step_class(batch_size).new(intermediate_db, discourse_db, shared_data, {})
    step.reporter = reporter
    step.trace = trace
    step
  end

  def create_tags(*names)
    names.each_with_index do |name, index|
      Migrations::Database::IntermediateDB::Tag.create(original_id: index + 1, name:, slug: name)
    end
  end

  before do
    allow(reporter).to receive(:with_progress).and_yield(progress)
    allow(discourse_db).to receive(:copy_data) { |_table, _columns, rows| @copied_rows = rows.to_a }
  end

  it "transforms rows one by one when no batch size is set" do
    create_tags("a", "b", "c")

    build_step.execute

    expect(trace).to eq([[:row, "a"], [:row, "b"], [:row, "c"]])
    expect(copied_names).to eq(%w[a b c])
  end

  it "hands over a full batch before it transforms the batch's rows" do
    create_tags("a", "b", "c", "d")

    build_step(batch_size: 2).execute

    expect(trace).to eq(
      [[:batch, %w[a b]], [:row, "a"], [:row, "b"], [:batch, %w[c d]], [:row, "c"], [:row, "d"]],
    )
  end

  it "hands over the last batch even when it is not full" do
    create_tags("a", "b", "c")

    build_step(batch_size: 2).execute

    expect(trace.select { |kind, _| kind == :batch }).to eq([[:batch, %w[a b]], [:batch, %w[c]]])
    expect(copied_names).to eq(%w[a b c])
  end

  it "does not hand over an empty batch" do
    build_step(batch_size: 2).execute

    expect(trace).to be_empty
    expect(@copied_rows).to be_empty
  end

  it "keeps marking skipped rows in a batch" do
    create_tags("a", "skipped", "c")

    build_step(batch_size: 2).execute

    expect(
      @copied_rows.map { |row| row[Migrations::Importer::DiscourseDB::SKIP_ROW_MARKER] },
    ).to eq([nil, true, nil])
  end
end
