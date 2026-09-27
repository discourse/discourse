# frozen_string_literal: true

RSpec.describe "Migrations::Importer::Steps::TopicStatistics", :rails do
  include_context "with importer databases"

  self.use_transactional_tests = false if respond_to?(:use_transactional_tests=)

  let(:base_id) { 900_000 }
  let(:discourse_db) { Migrations::Importer::DiscourseDB.new }
  let(:shared_data) { instance_double(Migrations::Importer::SharedData) }
  let(:topic_id) { base_id + 1 }
  let(:user_id) { base_id + 2 }

  after do
    DB.exec("DELETE FROM posts WHERE topic_id >= :id", id: base_id)
    DB.exec("DELETE FROM topics WHERE id >= :id", id: base_id)
    DB.exec("DELETE FROM users WHERE id >= :id", id: base_id)
    discourse_db.close
  end

  it "updates topic statistics from its posts" do
    DB.exec(<<~SQL, id: user_id)
      INSERT INTO users (id, username, username_lower, trust_level, created_at, updated_at)
      VALUES (:id, 'alice', 'alice', 1, NOW(), NOW())
    SQL
    DB.exec(<<~SQL, id: topic_id, user_id:)
      INSERT INTO topics (id, title, category_id, user_id, last_post_user_id,
                          created_at, updated_at, bumped_at)
      VALUES (:id, 'A topic', 1, :user_id, :user_id, NOW(), NOW(), NOW())
    SQL
    DB.exec(<<~SQL, topic_id:, user_id:)
      INSERT INTO posts (topic_id, user_id, post_number, sort_order, raw, cooked,
                         post_type, created_at, updated_at, last_version_at)
      VALUES (:topic_id, :user_id, 1, 1, 'first', '', 1,
              '2024-01-01', '2024-01-01', '2024-01-01'),
             (:topic_id, :user_id, 2, 2, 'second', '', 1,
              '2024-01-02', '2024-01-02', '2024-01-02')
    SQL

    step =
      Migrations::Importer::Steps::TopicStatistics.new(
        intermediate_db,
        discourse_db,
        shared_data,
        {},
      )
    step.execute

    topic = Topic.find(topic_id)
    expect(topic.posts_count).to eq(2)
    expect(topic.highest_post_number).to eq(2)
    expect(topic.highest_staff_post_number).to eq(2)
    expect(topic.last_posted_at).to eq_time(Time.utc(2024, 1, 2))
    expect(topic.bumped_at).to eq_time(Time.utc(2024, 1, 2))
    expect(topic.last_post_user_id).to eq(user_id)
  end
end
