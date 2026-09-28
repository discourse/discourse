# frozen_string_literal: true

RSpec.describe "Migrations::Importer::Steps::TopicStatistics", :rails do
  include_context "with importer databases"

  self.use_transactional_tests = false if respond_to?(:use_transactional_tests=)

  let(:base_id) { 900_000 }
  let(:discourse_db) { Migrations::Importer::DiscourseDB.new }
  let(:shared_data) { Migrations::Importer::SharedData.new(discourse_db) }
  let(:existing_topic_id) { base_id + 1 }
  let(:unrelated_topic_id) { base_id + 2 }
  let(:new_topic_id) { base_id + 3 }
  let(:user_id) { base_id + 4 }
  let(:source_topic_id) { 500 }

  after do
    DB.exec("DELETE FROM posts WHERE topic_id >= :id", id: base_id)
    DB.exec("DELETE FROM topics WHERE id >= :id", id: base_id)
    DB.exec("DELETE FROM users WHERE id >= :id", id: base_id)
    discourse_db.close
  end

  it "updates imported and reused topics without changing unrelated topics" do
    first_post_id = base_id + 10
    second_post_id = first_post_id + 1
    unrelated_post_id = second_post_id + 1
    new_topic_post_id = unrelated_post_id + 1
    DB.exec(<<~SQL, id: user_id)
      INSERT INTO users (id, username, username_lower, trust_level, created_at, updated_at)
      VALUES (:id, 'alice', 'alice', 1, NOW(), NOW())
    SQL
    DB.exec(<<~SQL, id: existing_topic_id, user_id:)
      INSERT INTO topics (id, title, category_id, user_id, last_post_user_id,
                          created_at, updated_at, bumped_at)
      VALUES (:id, 'A topic', 1, :user_id, :user_id, NOW(), NOW(), NOW())
    SQL
    DB.exec(<<~SQL, id: unrelated_topic_id, user_id:)
      INSERT INTO topics (id, title, category_id, user_id, last_post_user_id, posts_count,
                          created_at, updated_at, bumped_at)
      VALUES (:id, 'An unrelated topic', 1, :user_id, :user_id, 42, NOW(), NOW(), NOW())
    SQL
    DB.exec(<<~SQL, id: new_topic_id, user_id:)
      INSERT INTO topics (id, title, category_id, user_id, last_post_user_id,
                          created_at, updated_at, bumped_at)
      VALUES (:id, 'A new topic', 1, :user_id, :user_id, NOW(), NOW(), NOW())
    SQL
    DB.exec(
      <<~SQL,
      INSERT INTO posts (id, topic_id, user_id, post_number, sort_order, raw, cooked,
                         post_type, created_at, updated_at, last_version_at)
      VALUES (:first_post_id, :existing_topic_id, :user_id, 1, 1, 'first', '', 1,
              '2024-01-01', '2024-01-01', '2024-01-01'),
             (:second_post_id, :existing_topic_id, :user_id, 2, 2, 'second', '', 1,
              '2024-01-02', '2024-01-02', '2024-01-02'),
             (:unrelated_post_id, :unrelated_topic_id, :user_id, 1, 1, 'unrelated', '', 1,
              '2024-01-03', '2024-01-03', '2024-01-03'),
             (:new_topic_post_id, :new_topic_id, :user_id, 1, 1, 'new', '', 1,
              '2024-01-04', '2024-01-04', '2024-01-04')
    SQL
      first_post_id:,
      second_post_id:,
      unrelated_post_id:,
      new_topic_post_id:,
      existing_topic_id:,
      unrelated_topic_id:,
      new_topic_id:,
      user_id:,
    )
    Migrations::Database::IntermediateDB::Topic.create(
      original_id: source_topic_id,
      existing_id: existing_topic_id,
      title: "A source topic",
    )
    shared_data[:first_imported_topic_id] = new_topic_id

    step =
      Migrations::Importer::Steps::TopicStatistics.new(
        intermediate_db,
        discourse_db,
        shared_data,
        {},
      )
    step.execute

    topic = Topic.find(existing_topic_id)
    expect(topic.posts_count).to eq(2)
    expect(topic.highest_post_number).to eq(2)
    expect(topic.highest_staff_post_number).to eq(2)
    expect(topic.last_posted_at).to eq_time(Time.utc(2024, 1, 2))
    expect(topic.bumped_at).to eq_time(Time.utc(2024, 1, 2))
    expect(topic.last_post_user_id).to eq(user_id)
    expect(Topic.find(unrelated_topic_id).posts_count).to eq(42)
    expect(Topic.find(new_topic_id).posts_count).to eq(1)
  end
end
