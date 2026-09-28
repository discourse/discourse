# frozen_string_literal: true

RSpec.describe "Migrations::Importer::Steps::Topics", :rails do
  include_context "with importer databases"

  self.use_transactional_tests = false if respond_to?(:use_transactional_tests=)

  let(:base_id) { 900_000 }
  let(:topic_id) { base_id + 1 }
  let(:user_id) { base_id + 2 }
  let(:discourse_db) { Migrations::Importer::DiscourseDB.new }
  let(:shared_data) { Migrations::Importer::SharedData.new(discourse_db) }
  let(:progress) { instance_double(Migrations::Reporting::Reporter::Progress, update: nil) }
  let(:reporter) { instance_double(Migrations::Reporting::Reporter::StepHandle) }

  before do
    allow(reporter).to receive(:with_progress).and_yield(progress)
    allow(reporter).to receive(:notice)

    DB.exec(<<~SQL, id: user_id)
      INSERT INTO users (id, username, username_lower, trust_level, created_at, updated_at)
      VALUES (:id, 'alice', 'alice', 1, NOW(), NOW())
    SQL
    DB.exec(<<~SQL, id: topic_id, user_id:)
      INSERT INTO topics (id, title, category_id, user_id, last_post_user_id,
                          created_at, updated_at, bumped_at)
      VALUES (:id, 'Existing topic', 1, :user_id, :user_id, NOW(), NOW(), NOW())
    SQL
  end

  after do
    DB.exec("DELETE FROM topics WHERE id >= :id", id: base_id)
    DB.exec("DELETE FROM users WHERE id >= :id", id: base_id)
    discourse_db.close
  end

  it "maps a source topic to an existing destination topic" do
    Migrations::Database::IntermediateDB::Topic.create(
      original_id: 10,
      existing_id: topic_id,
      title: "Source topic",
    )

    step = Migrations::Importer::Steps::Topics.new(intermediate_db, discourse_db, shared_data, {})
    step.reporter = reporter
    step.execute

    mappings =
      intermediate_db.query(
        "SELECT original_id, discourse_id FROM mapped.ids WHERE type = ?",
        mapping_type::TOPICS,
      )
    expect(mappings).to eq([{ original_id: 10, discourse_id: topic_id }])
    expect(DB.query_single("SELECT title FROM topics WHERE id = :id", id: topic_id)).to eq(
      ["Existing topic"],
    )
  end

  it "imports a topic when no existing destination topic is referenced" do
    Migrations::Database::IntermediateDB::Topic.create(
      original_id: 11,
      archetype: Archetype.private_message,
      created_at: Time.zone.now,
      pinned_globally: false,
      title: "New topic",
    )

    step = Migrations::Importer::Steps::Topics.new(intermediate_db, discourse_db, shared_data, {})
    step.reporter = reporter
    step.execute

    discourse_id =
      intermediate_db.query_value(
        "SELECT discourse_id FROM mapped.ids WHERE original_id = ? AND type = ?",
        11,
        mapping_type::TOPICS,
      )
    expect(DB.query_single("SELECT title FROM topics WHERE id = :id", id: discourse_id)).to eq(
      ["New topic"],
    )
    expect(shared_data[:first_imported_topic_id]).to eq(discourse_id)
  end
end
