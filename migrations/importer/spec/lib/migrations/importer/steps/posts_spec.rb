# frozen_string_literal: true

# The step's class body reads Rails constants, so it is only named inside the
# lazily evaluated blocks below - the file is loaded even when `:rails` is
# excluded.
RSpec.describe "Migrations::Importer::Steps::Posts", :rails do
  include_context "with importer databases"

  # The step writes through its own PostgreSQL connection, which never sees an
  # open transaction of the example. Everything this spec creates lives above
  # `base_id` and is deleted again afterwards. The guard keeps the file loadable
  # without a Rails boot, where the examples are excluded anyway.
  self.use_transactional_tests = false if respond_to?(:use_transactional_tests=)

  let(:base_id) { 900_000 }
  let(:discourse_db) { Migrations::Importer::DiscourseDB.new }
  let(:shared_data) { instance_double(Migrations::Importer::SharedData) }
  let(:progress) { instance_double(Migrations::Reporting::Reporter::Progress, update: nil) }
  let(:reporter) { instance_double(Migrations::Reporting::Reporter::StepHandle) }
  let(:notices) { [] }
  let(:placeholder) { Migrations::Placeholder.new(nonce: "n") }

  let(:source_topic_id) { 500 }
  let(:topic_id) { base_id + 1 }
  let(:user_id) { base_id + 2 }

  before do
    allow(reporter).to receive(:with_progress).and_yield(progress)
    allow(reporter).to receive(:notice) { |message| notices << message }
  end

  after do
    DB.exec("DELETE FROM posts WHERE topic_id >= :id", id: base_id)
    DB.exec("DELETE FROM topics WHERE id >= :id", id: base_id)
    DB.exec("DELETE FROM users WHERE id >= :id", id: base_id)
    discourse_db.close
  end

  def create_destination_user(id, username)
    DB.exec(<<~SQL, id:, username:, username_lower: username.downcase)
      INSERT INTO users (id, username, username_lower, trust_level, created_at, updated_at)
      VALUES (:id, :username, :username_lower, 1, NOW(), NOW())
    SQL
  end

  def create_destination_topic(id, last_post_user_id)
    DB.exec(<<~SQL, id:, user_id: last_post_user_id)
      INSERT INTO topics (id, title, category_id, user_id, last_post_user_id,
                          created_at, updated_at, bumped_at)
      VALUES (:id, 'A topic', 1, :user_id, :user_id, NOW(), NOW(), NOW())
    SQL
  end

  def create_source_post(original_id, attributes = {})
    Migrations::Database::IntermediateDB::Post.create(
      original_id:,
      topic_id: source_topic_id,
      user_id: 1,
      raw: "post #{original_id}",
      created_at: Time.utc(2024, 1, 1) + original_id,
      **attributes,
    )
  end

  def destination_posts
    DB.query("SELECT * FROM posts WHERE topic_id >= #{base_id} ORDER BY post_number")
  end

  def destination_topic
    DB.query("SELECT * FROM topics WHERE id = #{topic_id}").first
  end

  def execute_step
    step = Migrations::Importer::Steps::Posts.new(intermediate_db, discourse_db, shared_data, {})
    step.reporter = reporter
    step.execute
    step
  end

  before do
    create_destination_user(user_id, "alice")
    create_destination_topic(topic_id, user_id)
    add_mapping(source_topic_id, mapping_type::TOPICS, topic_id)
    add_mapping(1, mapping_type::USERS, user_id)
  end

  it "copies the posts with the numbers of the pre-pass" do
    create_source_post(1, post_number: 4)
    create_source_post(2)

    execute_step

    posts = destination_posts
    expect(posts.map(&:post_number)).to eq([4, 5])
    expect(posts.map(&:sort_order)).to eq([4, 5])
    expect(posts.map(&:raw)).to eq(["post 1", "post 2"])
    expect(posts.map(&:user_id)).to eq([user_id, user_id])
    expect(posts.map(&:word_count)).to eq([2, 2])
    expect(posts.map(&:cooked)).to eq(["", ""])
    expect(posts.map(&:last_version_at)).to eq(posts.map(&:created_at))
  end

  it "maps the ids of the copied posts" do
    create_source_post(1)

    execute_step

    rows =
      intermediate_db.query(
        "SELECT original_id, discourse_id FROM mapped.ids WHERE type = ?",
        mapping_type::POSTS,
      )
    expect(rows.size).to eq(1)
    expect(rows.first[:original_id]).to eq(1)
    expect(rows.first[:discourse_id]).to eq(destination_posts.first.id)
  end

  it "resolves a quote that names a post copied later in the run" do
    token = placeholder.mint(:quote)
    create_source_post(1, raw: "#{token}quoted[/quote]")
    create_source_post(2)
    Migrations::Database::IntermediateDB::EmbedQuote.create(
      owner_type: enums::EmbedOwner::POST,
      owner_id: 1,
      placeholder: token,
      quoted_post_id: 2,
      quoted_user_id: 1,
    )

    execute_step

    expect(destination_posts.first.raw).to eq(
      "[quote=\"alice, post:2, topic:#{topic_id}\"]quoted[/quote]",
    )
  end

  it "reads the reply number from the pre-pass" do
    create_source_post(1)
    create_source_post(2, reply_to_post_id: 1)

    execute_step

    expect(destination_posts.map(&:reply_to_post_number)).to eq([nil, 1])
  end

  it "skips a post whose topic was not imported" do
    create_source_post(1)
    Migrations::Database::IntermediateDB::Post.create(
      original_id: 2,
      topic_id: 501,
      raw: "orphan",
      created_at: Time.utc(2024, 1, 1),
    )

    execute_step

    expect(destination_posts.size).to eq(1)
    expect(notices).to include(a_string_including("Skipped post 2"))
  end

  it "reports an embed it could not resolve" do
    token = placeholder.mint(:poll)
    create_source_post(1, raw: "before #{token} after")
    Migrations::Database::IntermediateDB::EmbedPoll.create(
      owner_type: enums::EmbedOwner::POST,
      owner_id: 1,
      placeholder: token,
      poll_id: 77,
    )

    execute_step

    rows = intermediate_db.query("SELECT * FROM mapped.unresolved_embeds")
    expect(rows.size).to eq(1)
    expect(rows.first[:kind]).to eq("poll")
    expect(rows.first[:entity_id]).to eq("77")
    expect(rows.first[:owner_id]).to eq(1)
    expect(notices).to include(a_string_including("1 poll embeds"))
  end

  it "updates the counters of the topics it touched" do
    create_source_post(1)
    create_source_post(2)

    execute_step

    topic = destination_topic
    last_post = destination_posts.last
    expect(topic.posts_count).to eq(2)
    expect(topic.highest_post_number).to eq(2)
    expect(topic.highest_staff_post_number).to eq(2)
    expect(topic.last_posted_at).to eq_time(last_post.created_at)
    expect(topic.bumped_at).to eq_time(last_post.created_at)
    expect(topic.last_post_user_id).to eq(user_id)
  end

  it "copies nothing a second time" do
    create_source_post(1)
    execute_step

    create_source_post(2)
    execute_step

    posts = destination_posts
    expect(posts.map(&:post_number)).to eq([1, 2])
    expect(posts.map(&:raw)).to eq(["post 1", "post 2"])
  end

  it "puts a placeholder text into an empty body" do
    create_source_post(1, raw: "   ")

    execute_step

    expect(destination_posts.first.raw).to eq(I18n.t("importer.posts.empty_raw"))
  end

  it "removes NUL bytes from the body" do
    create_source_post(1, raw: "a\u0000b")

    execute_step

    expect(destination_posts.first.raw).to eq("ab")
  end
end
