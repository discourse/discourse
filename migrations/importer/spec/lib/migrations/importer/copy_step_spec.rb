# frozen_string_literal: true

RSpec.describe "Migrations::Importer::CopyStep" do
  before do
    unless defined?(Discourse::SYSTEM_USER_ID)
      stub_const("Discourse", Module.new)
      stub_const("Discourse::SYSTEM_USER_ID", -1)
    end
  end

  around do |example|
    Dir.mktmpdir do |directory|
      @database = Migrations::Database::Connection.new(path: File.join(directory, "records.db"))
      @database.execute("CREATE TABLE records (id INTEGER)")
      @database.execute("INSERT INTO records VALUES (1), (2), (3), (4)")
      example.run
    ensure
      @database&.close
    end
  end

  let(:step_class) do
    Class.new(Migrations::Importer::CopyStep) do
      rows_query "SELECT id FROM records WHERE id >= ? ORDER BY id", 2

      attr_reader :events
      public :fetch_rows # rubocop:disable Style/AccessModifierDeclarations -- Expose the inherited iterator.

      private

      def setup
        @events = []
      end

      def transform_row(row)
        @events << [:transform, row[:id]]
        { id: row[:id] * 10 } if row[:id].odd?
      end

      def update_progressbar
        @events << [:progress, @stats.skip_count]
      end
    end
  end
  let(:step) { step_class.new(@database, nil, nil, nil) }

  it "defers work until consumption and reports progress after each transformed or skipped row" do
    rows = step.fetch_rows
    expect(step.events).to be_empty

    rows.each { |row| step.events << [:consume, row] }

    marker = Migrations::Importer::DiscourseDB::SKIP_ROW_MARKER
    expect(step.events).to eq(
      [
        [:transform, 2],
        [:consume, { :id => 2, marker => true }],
        [:progress, 1],
        [:transform, 3],
        [:consume, { id: 30 }],
        [:progress, 0],
        [:transform, 4],
        [:consume, { :id => 4, marker => true }],
        [:progress, 1],
      ],
    )
  end

  it "stops at an early batch exit and releases the database operation" do
    marker = Migrations::Importer::DiscourseDB::SKIP_ROW_MARKER
    expect(step.fetch_rows.each_slice(2).first).to eq([{ :id => 2, marker => true }, { id: 30 }])
    expect(step.events).to eq([[:transform, 2], [:progress, 1], [:transform, 3]])
    expect(@database.query_value("SELECT 42")).to eq(42)
    expect { @database.close }.not_to raise_error
  end

  it "propagates consumer errors and releases the database operation" do
    expect { step.fetch_rows.each { raise "consumer failed" } }.to raise_error("consumer failed")
    expect(step.events).to eq([[:transform, 2]])
    expect { @database.close }.not_to raise_error
  end
end
