# frozen_string_literal: true

require "tmpdir"

RSpec.describe Migrations::Converters::Discourse::CustomEmojis do
  subject(:processor) { described_class.processor_class.new({}) }

  around do |example|
    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "intermediate.db")
      Migrations::Database.migrate(
        db_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )
      @db = Migrations::Database.connect(db_path)
      Migrations::Database::IntermediateDB.setup(@db)
      example.run
    ensure
      Migrations::Database::IntermediateDB.setup(nil)
    end
  end

  def rows(table)
    [].tap { |out| @db.query("SELECT * FROM #{table}") { |row| out << row } }
  end

  it "stores the emoji, keyed by the upload's content-hash reference" do
    processor.process(
      {
        id: 5,
        name: "parrot",
        group: "animals",
        upload_id: "8f14e45fceea167a5a36dedd4bea2543",
        created_at: Time.utc(2020, 1, 2, 3, 4, 5),
      },
    )

    expect(rows("custom_emojis")).to contain_exactly(
      hash_including(
        original_id: 5,
        name: "parrot",
        group: "animals",
        upload_id: "8f14e45fceea167a5a36dedd4bea2543",
      ),
    )
  end

  it "keeps a nil group for an ungrouped emoji" do
    processor.process({ id: 6, name: "smile", group: nil, upload_id: "abc", created_at: nil })

    expect(rows("custom_emojis")).to contain_exactly(hash_including(original_id: 6, group: nil))
  end
end
