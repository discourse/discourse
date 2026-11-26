# frozen_string_literal: true

require_relative "../../../../script/bulk_import/discourse_merger/merger"

RSpec.describe BulkImport::DiscourseMerge::Merger, "#fix_category_descriptions" do
  fab!(:category)
  fab!(:description, :topic)
  fab!(:unrelated_topic, :topic)

  it "preserves reused category descriptions even when legacy import IDs overlap" do
    category.update_columns(topic_id: description.id)
    CategoryCustomField.create!(category_id: category.id, name: "import_id", value: "legacy")
    merger = described_class.allocate
    plan =
      BulkImport::DiscourseMerge::Plan.new(
        {
          "format_version" => 1,
          "topics" => [],
          "categories" => [
            {
              "key" => "existing",
              "operation" => "preserve_existing",
              "destination_category_id" => category.id,
            },
          ],
        },
      )
    merger.instance_variable_set(:@plan, plan)
    merger.instance_variable_set(:@source_categories, { 100 => { "topic_id" => description.id } })
    merger.instance_variable_set(:@categories, { 100 => category.id })
    merger.instance_variable_set(:@topics, { description.id => unrelated_topic.id })

    merger.fix_category_descriptions

    expect(category.reload.topic_id).to eq(description.id)
  end
end

RSpec.describe BulkImport::DiscourseMerge::Merger do
  def build_merger(**ivars)
    described_class.allocate.tap do |merger|
      { auto_group_ids: Group::AUTO_GROUPS.values, audit: [] }.merge(ivars)
        .each { |name, value| merger.instance_variable_set(:"@#{name}", value) }
    end
  end

  def source_returning(rows)
    instance_double(PG::Connection, exec: rows)
  end

  describe "#copy_user_stuff" do
    it "excludes session-bound push subscriptions from the models copied for users" do
      merger = build_merger(merged_user_ids: [], historical_bot_ids: [])
      allow(merger).to receive(:copy_model)

      merger.copy_user_stuff

      expect(merger).to have_received(:copy_model).with(UserVisit, any_args)
      expect(merger).not_to have_received(:copy_model).with(PushSubscription, any_args)
    end
  end

  it "maps an automatic plugin group by name when its ID differs across sites" do
    group = Fabricate(:group, name: "discourse_ai_users", automatic: true)
    canonical_bot = Fabricate(:user, id: -2)
    source = instance_double(PG::Connection)
    allow(source).to receive(:exec).with("SELECT id, name FROM groups WHERE automatic").and_return(
      [{ "id" => "9999", "name" => group.name }],
    )
    allow(source).to receive(:exec_params).with(
      "SELECT username FROM users WHERE id=$1",
      [-1],
    ).and_return([{ "username" => User.find(-1).username }])
    allow(source).to receive(:exec_params).with(
      "SELECT username FROM users WHERE id=$1",
      [-2],
    ).and_return([{ "username" => canonical_bot.username }])
    merger = build_merger(source_raw_connection: source)

    merger.load_imported_ids

    expect(merger.group_id_from_imported_id(9999)).to eq(group.id)
  end

  describe "#fix_polls" do
    fab!(:post)

    # Core specs run without plugins loaded, so the poll plugin is stood in for.
    before do
      poll = Struct.new(:post_id).new(post.id)
      poll_model = Class.new { define_singleton_method(:find_by_id) { |id| poll if id == 10 } }

      RSpec::Mocks::ConstantMutator.stub("DiscoursePoll::HAS_POLLS", "has_polls")
      RSpec::Mocks::ConstantMutator.stub("Poll", poll_model)
    end

    def has_polls_flag?(post)
      PostCustomField.exists?(post_id: post.id, name: "has_polls")
    end

    it "flags the posts of merged polls" do
      build_merger(polls: { "1" => 10 }).fix_polls

      expect(has_polls_flag?(post)).to eq(true)
    end

    it "flags polls on deleted posts" do
      post.trash!

      build_merger(polls: { "1" => 10 }).fix_polls

      expect(has_polls_flag?(post)).to eq(true)
    end

    it "skips polls that were not copied" do
      expect { build_merger(polls: { "1" => 11 }).fix_polls }.not_to raise_error
    end
  end

  describe "#fix_primary_keys" do
    fab!(:post_custom_field) { PostCustomField.create!(post: Fabricate(:post), name: "a") }

    let(:sequence_name) { PostCustomField.sequence_name }

    def last_sequence_value
      DB.query_single("SELECT last_value FROM #{sequence_name}").first
    end

    def fix_primary_keys(val)
      build_merger(
        raw_connection: ActiveRecord::Base.connection.raw_connection,
        sequences: {
          sequence_name => val,
        },
      ).fix_primary_keys
    end

    it "does not move a sequence below the ids already in the table" do
      fix_primary_keys(1)

      expect(last_sequence_value).to be > post_custom_field.id
    end

    it "advances a sequence to the counter of the copied rows" do
      val = post_custom_field.id + 100

      fix_primary_keys(val)

      expect(last_sequence_value).to eq(val)
    end
  end

  describe "#fix_featured_topic" do
    fab!(:existing_user, :user)
    fab!(:merged_user, :user)
    fab!(:old_topic, :topic)
    fab!(:new_topic, :topic)

    let(:merger) do
      build_merger(first_new_user_id: merged_user.id, topics: { old_topic.id => new_topic.id })
    end

    before do
      existing_user.user_profile.update_columns(featured_topic_id: old_topic.id)
      merged_user.user_profile.update_columns(featured_topic_id: old_topic.id)
    end

    it "remaps the featured topic of merged users only" do
      merger.fix_featured_topic

      expect(merged_user.user_profile.reload.featured_topic_id).to eq(new_topic.id)
      expect(existing_user.user_profile.reload.featured_topic_id).to eq(old_topic.id)
    end

    it "remaps profiles whose copied attributes no longer pass validation" do
      merged_user.user_profile.update_columns(bio_raw: "a" * 3001)

      merger.fix_featured_topic

      expect(merged_user.user_profile.reload.featured_topic_id).to eq(new_topic.id)
    end
  end

  describe "#merge_same_named_rows" do
    fab!(:destination_group) { Fabricate(:group, name: "support_team") }
    fab!(:other_group, :group)

    def copied_rows(sql)
      DB.query_hash(sql).to_h { |row| [row["id"], row["name"]] }
    end

    it "selects every row when no names collide" do
      tag_group = Fabricate(:tag_group, name: "Staff only")
      tag_groups = {}
      merger = build_merger(tag_groups:)
      allow(merger).to receive(:source_raw_connection).and_return(
        source_returning([{ "id" => "42", "name" => "Something else" }]),
      )

      sql = nil
      expect {
        sql = merger.merge_same_named_rows(TagGroup, tag_groups, max_name_length: 100)
      }.not_to output.to_stdout

      expect(tag_groups).to be_empty
      expect(copied_rows(sql)).to eq(tag_group.id => "Staff only")
    end

    context "when SEPARATE_SAME_NAMED_GROUPS is enabled" do
      it "copies same-named source rows under the first free name" do
        Fabricate(:group, name: "Support_Team_1")
        groups = {}
        merger = build_merger(groups:, separate_same_named_groups: true)
        allow(merger).to receive(:source_raw_connection).and_return(
          source_returning(
            [
              { "id" => other_group.id.to_s, "name" => "Support_Team" },
              { "id" => "4242", "name" => "support_team_2" },
            ],
          ),
        )

        sql = nil
        expect {
          sql =
            merger.merge_same_named_rows(
              Group,
              groups,
              where: "automatic = false",
              max_name_length: 20,
            )
        }.not_to output.to_stdout

        expect(groups).to be_empty
        expect(copied_rows(sql)).to include(
          other_group.id => "Support_Team_3",
          destination_group.id => "support_team",
        )
      end

      it "shortens the name to fit the maximum length" do
        groups = {}
        merger = build_merger(groups:, separate_same_named_groups: true)
        allow(merger).to receive(:source_raw_connection).and_return(
          source_returning([{ "id" => other_group.id.to_s, "name" => "SUPPORT_TEAM" }]),
        )

        sql =
          merger.merge_same_named_rows(
            Group,
            groups,
            where: "automatic = false",
            max_name_length: 12,
          )

        expect(copied_rows(sql)[other_group.id]).to eq("SUPPORT_TE_1")
      end
    end
  end

  describe "join table dedupe guards" do
    fab!(:user)
    fab!(:other_user, :user)
    fab!(:category)
    fab!(:other_category, :category)
    fab!(:tag)
    fab!(:other_tag, :tag)
    fab!(:tag_group)
    fab!(:other_tag_group, :tag_group)
    fab!(:group)
    fab!(:upload)
    fab!(:post)

    def expect_guard(record, **changes)
      klass = record.class
      original = record.attributes
      incoming = original.merge(changes.stringify_keys)
      rows =
        [original, incoming, incoming].map do |row|
          row.transform_values { |value| klass.connection.type_cast(value) }
        end
      raw_source =
        instance_double(PG::Connection, exec: [], transaction_status: PG::PQTRANS_INTRANS)
      allow(raw_source).to receive(:exec).with(/FETCH/).and_return(rows)
      map = (original.values + incoming.values).grep(Integer).index_with(&:itself)
      merger =
        build_merger(
          source_raw_connection: raw_source,
          raw_connection: ActiveRecord::Base.connection.raw_connection,
          encoder: PG::TextEncoder::CopyRow.new,
          sequences: {
          },
          merged_user_ids: [],
          tags: map,
          users: map,
          groups: map,
          categories: map,
          tag_groups: map,
          topics: map,
          posts: map,
          uploads: map,
        )

      merger.copy_model_rows(klass)

      expect(klass.where(original.except("id")).pluck(:id)).to eq([record.id])
      expect(klass.where(incoming.except("id")).count).to eq(1)
    end

    it "keeps existing tag and category group associations" do
      expect_guard(TagGroupMembership.create!(tag_group: tag_group, tag: tag), tag_id: other_tag.id)
      expect_guard(
        CategoryTagGroup.create!(category: category, tag_group: tag_group),
        category_id: other_category.id,
      )
      required =
        CategoryRequiredTagGroup.create!(category: category, tag_group: tag_group, min_count: 1)
      expect_guard(required, tag_group_id: other_tag_group.id)
      permission =
        TagGroupPermission.create!(tag_group: tag_group, group: group, permission_type: 1)
      expect_guard(permission, tag_group_id: other_tag_group.id)
    end

    it "keeps existing notification preferences" do
      tag_default =
        GroupTagNotificationDefault.create!(group: group, tag: tag, notification_level: 1)
      expect_guard(tag_default, tag_id: other_tag.id)
      category_default =
        GroupCategoryNotificationDefault.create!(
          group: group,
          category: category,
          notification_level: 1,
        )
      expect_guard(category_default, category_id: other_category.id)
      expect_guard(
        CategoryUser.create!(category: category, user: user, notification_level: 1),
        category_id: other_category.id,
      )
    end

    it "keeps existing muted and ignored user relationships" do
      muted = MutedUser.create!(user: user, muted_user: other_user)
      expect_guard(muted, user_id: other_user.id, muted_user_id: user.id)
      ignored =
        IgnoredUser.create!(user: user, ignored_user: other_user, expiring_at: 1.month.from_now)
      expect_guard(ignored, user_id: other_user.id, ignored_user_id: user.id)
    end

    it "keeps existing user and polymorphic upload associations" do
      expect_guard(UserUpload.create!(upload: upload, user: user), user_id: other_user.id)
      expect_guard(
        UploadReference.create!(upload: upload, target: post),
        target_type: "User",
        target_id: user.id,
      )
    end
  end

  it "copies remapped associations from a separate source database with overlapping IDs" do
    destination = ActiveRecord::Base.connection.raw_connection
    source = PG.connect(destination.conninfo_hash.compact_blank.merge(dbname: "postgres"))
    category = Fabricate(:category)
    wrong_form = Fabricate(:form_template)
    target_form = Fabricate(:form_template)
    group = Fabricate(:group)
    user = Fabricate(:user)
    tag = Fabricate(:tag)
    source_group_id = group.id + 100
    user.update_columns(flair_group_id: source_group_id)
    plan =
      BulkImport::DiscourseMerge::Plan.new(
        "format_version" => 1,
        "topics" => [],
        "categories" => [{ "key" => "source:1", "source_category_id" => 1 }],
        "form_templates" => {
          wrong_form.id.to_s => target_form.id,
        },
        "policy" => {
        },
      )
    merger =
      build_merger(
        raw_connection: destination,
        source_raw_connection: source,
        encoder: PG::TextEncoder::CopyRow.new,
        plan: plan,
        selection: BulkImport::DiscourseMerge::Selection.new(plan),
        merged_user_ids: [],
        sequences: {
        },
        categories: {
          1 => category.id,
        },
        users: (1..1001).index_with { user.id },
        groups: {
          source_group_id => group.id,
        },
        tags: {
          1 => tag.id,
        },
        notifications: {
        },
        first_new_user_id: user.id,
      )
    source.exec(<<~SQL)
      CREATE TEMP TABLE category_form_templates (id bigint, category_id bigint, form_template_id bigint, created_at timestamp DEFAULT now(), updated_at timestamp DEFAULT now());
      CREATE TEMP TABLE tag_users (id bigint, user_id bigint, tag_id bigint, notification_level integer, created_at timestamp DEFAULT now(), updated_at timestamp DEFAULT now());
      INSERT INTO category_form_templates (id, category_id, form_template_id) VALUES (1, 1, #{wrong_form.id});
      INSERT INTO tag_users (id, user_id, tag_id, notification_level)
      SELECT id, id, 1, 1 FROM generate_series(2, 1001) AS id;
      INSERT INTO tag_users (id, user_id, tag_id, notification_level) VALUES (1, 1, 1, 3);
    SQL
    source.exec("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY")

    merger.copy_model(CategoryFormTemplate)
    merger.copy_model(TagUser)
    merger.fix_user_columns

    expect(category.form_templates.pluck(:id)).to eq([target_form.id])
    expect(TagUser.where(user: user, tag: tag).pluck(:notification_level)).to eq([3])
    expect(user.reload.flair_group_id).to eq(group.id)
    expect(source.exec("SELECT count(*) FROM tag_users").getvalue(0, 0)).to eq("1001")
  ensure
    source&.close
  end

  describe "#copy_model_rows" do
    let(:source_tables) { {} }
    let(:merger) do
      build_merger(
        raw_connection: ActiveRecord::Base.connection.raw_connection,
        encoder: PG::TextEncoder::CopyRow.new,
        merged_user_ids: [],
        sequences: {
        },
        users: {
        },
        groups: {
        },
        categories: {
        },
        topics: {
        },
        posts: {
        },
        tags: {
        },
        tag_groups: {
        },
        uploads: {
        },
        badges: {
        },
        badge_groupings: {
        },
        polls: {
        },
        poll_options: {
        },
        auto_group_ids: Group::AUTO_GROUPS.values,
      )
    end

    # Rows come back from PG as string-valued hashes in column order.
    def add_source_row(klass, **values)
      row = klass.column_names.index_with { nil }
      row.merge!(values.transform_keys(&:to_s).transform_values { |value| value&.to_s })
      (source_tables[klass.table_name] ||= []) << row
    end

    before do
      source = instance_double(PG::Connection)
      table = nil
      allow(source).to receive(:transaction_status).and_return(PG::PQTRANS_INTRANS)
      allow(source).to receive(:exec) do |sql|
        table = sql[/FROM\s+(\w+)/i, 1] if sql.start_with?("DECLARE")
        sql.start_with?("FETCH") ? source_tables.fetch(table, []) : []
      end
      allow(merger).to receive(:source_raw_connection).and_return(source)
      allow(merger).to receive(:puts)
    end

    it "registers mappings that the lookup helpers can resolve" do
      category = Fabricate(:category)
      merger.instance_variable_get(:@categories)[42] = category.id
      timestamp = 1.day.ago.to_formatted_s(:db)

      add_source_row(TagGroup, id: 7, name: "Colors", created_at: timestamp, updated_at: timestamp)
      add_source_row(
        CategoryTagGroup,
        id: 3,
        category_id: 42,
        tag_group_id: 7,
        created_at: timestamp,
        updated_at: timestamp,
      )
      add_source_row(
        BadgeGrouping,
        id: 5,
        name: "Extra",
        position: 20,
        created_at: timestamp,
        updated_at: timestamp,
      )

      merger.copy_model_rows(TagGroup, mapping: merger.instance_variable_get(:@tag_groups))
      merger.copy_model_rows(CategoryTagGroup, skip_processing: true)
      merger.copy_model_rows(
        BadgeGrouping,
        mapping: merger.instance_variable_get(:@badge_groupings),
        skip_processing: true,
      )

      tag_group = TagGroup.find_by!(name: "Colors")
      expect(merger.tag_group_id_from_imported_id("7")).to eq(tag_group.id)
      expect(CategoryTagGroup.where(category_id: category.id).pluck(:tag_group_id)).to eq(
        [tag_group.id],
      )
      expect(merger.badge_grouping_id_from_imported_id("5")).to eq(
        BadgeGrouping.find_by!(name: "Extra").id,
      )
    end

    it "ignores the converter pipeline's processors inherited from Base" do
      user = Fabricate(:user)
      topic = Fabricate(:private_message_topic)
      merger.instance_variable_get(:@users)[21] = user.id
      merger.instance_variable_get(:@topics)[31] = topic.id
      created_at = Time.zone.parse("2020-01-02 03:04:05")

      add_source_row(
        TopicAllowedUser,
        id: 6,
        user_id: 21,
        topic_id: 31,
        created_at: created_at.to_formatted_s(:db),
        updated_at: created_at.to_formatted_s(:db),
      )

      merger.copy_model_rows(TopicAllowedUser)

      expect(TopicAllowedUser.find_by!(topic: topic, user: user).created_at).to eq_time(created_at)
    end

    it "still runs processors defined by the merger" do
      tag = Fabricate(:tag)
      merger.instance_variable_get(:@tags)[9] = tag.id
      timestamp = 1.day.ago.to_formatted_s(:db)

      add_source_row(
        TagGroup,
        id: 7,
        name: "Colors",
        parent_tag_id: 9,
        created_at: timestamp,
        updated_at: timestamp,
      )

      merger.copy_model_rows(TagGroup, mapping: merger.instance_variable_get(:@tag_groups))

      expect(TagGroup.find_by!(name: "Colors").parent_tag_id).to eq(tag.id)
    end

    it "maps only the rows that a processor keeps" do
      timestamp = 1.day.ago.to_formatted_s(:db)
      add_source_row(TagGroup, id: 7, name: "Kept", created_at: timestamp, updated_at: timestamp)
      add_source_row(TagGroup, id: 8, name: "Skipped", created_at: timestamp, updated_at: timestamp)
      allow(merger).to receive(:process_tag_group) do |tag_group|
        tag_group unless tag_group["name"] == "Skipped"
      end

      merger.copy_model_rows(TagGroup, mapping: merger.instance_variable_get(:@tag_groups))

      expect(merger.tag_group_id_from_imported_id(7)).to eq(TagGroup.find_by!(name: "Kept").id)
      expect(merger.tag_group_id_from_imported_id(8)).to be_nil
    end
  end
end

RSpec.describe BulkImport::DiscourseMerge::Merger, "#process_post_revision" do
  it "preserves the identity of a deleted source editor alongside the imported revision" do
    merger = described_class.allocate
    merger.instance_variable_set(:@users, { -1 => -1, 3 => 10 })
    merger.instance_variable_set(:@original_authors, {})
    fallbacks = []
    merger.instance_variable_set(:@revision_author_fallbacks, fallbacks)
    row = { "id" => "17", "post_id" => 60, "user_id" => "4", "modifications" => nil }
    row["original_editor_id"] = merger.send(:normalize_author!, row, "post_revisions")
    row["id"] = 25
    expect(merger.process_post_revision(row)["user_id"]).to eq("-1")
    expect(fallbacks).to eq(
      [{ revision_id: 25, post_id: 60, original_editor_id: 4, original_user_ids: [4] }],
    )
    expect(merger.instance_variable_get(:@original_authors)).to eq(
      "post_revisions" => [{ "id" => 17, "user_id" => 4 }],
    )
  end
end
