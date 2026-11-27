# frozen_string_literal: true

require_relative "../../../../script/bulk_import/discourse_merger/merger"

RSpec.describe BulkImport::DiscourseMerge::Merger do
  fab!(:user)

  def merger_for(tables, reuse: [], **values)
    source = instance_double(PG::Connection)
    allow(source).to receive(:exec) { |sql| tables.fetch(sql[/FROM\s+(\w+)/i, 1], []) }
    allow(BulkImport::DiscourseMerge::SourceRows).to receive(:each).with(
      source,
      /\ASELECT /,
    ) do |connection, sql, &block|
      connection.exec(sql).each(&block)
    end
    described_class.allocate.tap do |merger|
      {
        plan: Struct.new(:data).new({ "upload_policy" => { "reuse" => reuse } }),
        raw_connection: ActiveRecord::Base.connection.raw_connection,
        source_raw_connection: source,
        encoder: PG::TextEncoder::CopyRow.new,
        sequences: {
        },
        users: {
          11 => user.id,
        },
        uploads: {
        },
        optimized_images: {
        },
        original_authors: {
        },
        source_base_url: "https://pynq.example",
        configuration: Struct.new(:data).new({ "destination_url" => "https://amd.example" }),
      }.merge(values).each { |name, value| merger.instance_variable_set(:"@#{name}", value) }
      allow(merger).to receive(:checkpoint)
    end
  end

  def source_row(record, **values)
    record.attributes.merge(values.transform_keys(&:to_s)).transform_values { |value| value&.to_s }
  end

  it "imports remote originals and optimized metadata with working upload short URLs and no file bytes" do
    original = Fabricate(:upload)
    thumbnail = Fabricate(:optimized_image, upload: original)
    row =
      source_row(
        original,
        id: 91,
        user_id: 11,
        sha1: "f" * 40,
        url: "/uploads/default/original/remote.png",
      )
    image =
      source_row(
        thumbnail,
        id: 92,
        upload_id: 91,
        url: "https://cdn.pynq.example/optimized/remote.png",
      )
    merger = merger_for({ "uploads" => [row], "optimized_images" => [image] })

    merger.copy_remote_uploads

    imported = Upload.find(merger.maps.fetch(:uploads).fetch(91))
    expect(imported.url).to eq("https://pynq.example/uploads/default/original/remote.png")
    expect(Upload.find_by!(sha1: Upload.sha1_from_short_url(imported.short_url))).to eq(imported)
    optimized = OptimizedImage.find(merger.maps.fetch(:optimized_images).fetch(92))
    expect(optimized.upload_id).to eq(imported.id)
    expect(optimized.url).to eq(image.fetch("url"))
  end

  it "normalizes a destination original in place and imports a prepared source with working post URLs" do
    original = Fabricate(:upload)
    old_url = "/uploads/default/original/1X/#{original.sha1}.png"
    original.update_columns(url: old_url)
    post = Fabricate(:post)
    post.update_columns(raw: "![photo](#{original.short_url})", cooked: %(<img src="#{old_url}">))
    UploadReference.create!(target: post, upload: original)
    source_sha = "e" * 40
    source_url = "/uploads/default/original/1X/#{source_sha}.png"
    origin = "//bucket.s3.dualstack.us-west-2.amazonaws.com"
    settings = {
      "destination_url" => "https://amd.example",
      "source_url" => "https://pynq.example",
    }
    result = {
      "url" => "#{origin}/original/1X/#{original.sha1}.png",
      "etag" => "destination",
      "secure" => false,
    }
    incoming = result.merge("url" => "#{origin}/original/1X/#{source_sha}.png", "etag" => "source")
    state =
      instance_double(
        BulkImport::DiscourseMerge::PreparedUploads,
        target: {
          "origin" => origin,
          "cdn" => "https://cdn.example",
        },
      )
    allow(state).to receive(:each_receipt).with("destination").and_yield(
      "uploads",
      original.id,
      original.attributes,
      result,
    )
    allow(state).to receive(:receipt).with("source", "uploads", 91).and_return(incoming)
    media = BulkImport::DiscourseMerge::PreuploadedMedia.new(state, { "policy" => settings })
    media.update_destination!
    expect(original.reload.url).to eq(result.fetch("url"))
    expect(post.reload.cooked).to eq(
      %(<img src="https://cdn.example/original/1X/#{original.sha1}.png">),
    )
    expect(post.raw).to include(original.short_url)
    expect(UploadReference.exists?(target: post, upload: original)).to be(true)

    row = source_row(original, id: 91, user_id: 11, sha1: source_sha, url: source_url)
    importer = merger_for({ "uploads" => [row] }, prepared_media: media)
    importer.copy_remote_uploads
    copied = Upload.find(importer.maps.fetch(:uploads).fetch(91))
    expect(copied.url).to eq(incoming.fetch("url"))
    expect(Upload.find_by!(sha1: Upload.sha1_from_short_url(copied.short_url))).to eq(copied)
    expect(importer.media_urls.fetch(source_url)).to eq(
      "https://cdn.example/original/1X/#{source_sha}.png",
    )
  end

  it "reuses destination originals and optimized images while retaining destination metadata" do
    original = Fabricate(:upload)
    thumbnail = Fabricate(:optimized_image, upload: original)
    row =
      source_row(
        original,
        id: 91,
        user_id: 11,
        original_filename: "incoming-name.png",
        url: "https://cdn.pynq.example/original.png",
      )
    image = source_row(thumbnail, id: 92, upload_id: 91, url: "https://cdn.pynq.example/thumb.png")
    before = original.reload.attributes
    merger =
      merger_for(
        { "uploads" => [row], "optimized_images" => [image] },
        reuse: [{ "source_upload_id" => 91, "destination_upload_id" => original.id }],
      )

    expect { merger.copy_remote_uploads }.not_to change(Upload, :count)

    expect(merger.maps.fetch(:uploads)).to eq(91 => original.id)
    expect(merger.maps.fetch(:optimized_images)).to eq(92 => thumbnail.id)
    expect(original.reload.attributes).to eq(before)
    expect(merger.media_urls.fetch(row.fetch("url"))).to eq("https://amd.example#{original.url}")
  end

  it "refuses inconsistent size metadata before reusing a destination upload" do
    original = Fabricate(:upload)
    row = source_row(original, id: 91, filesize: original.filesize + 1)
    merger =
      merger_for(
        { "uploads" => [row] },
        reuse: [{ "source_upload_id" => 91, "destination_upload_id" => original.id }],
      )
    expect { merger.copy_remote_uploads }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /inconsistent size/,
    )
  end

  it "derives new staff/trust memberships from destination policy and preserves matched memberships" do
    imported = Fabricate(:user, admin: true, trust_level: 2)
    matched = Fabricate(:user, admin: false, moderator: false, trust_level: 0)
    GroupUser.where(user_id: imported.id, group_id: Group::AUTO_GROUPS.values).delete_all
    matched_groups = matched.groups.pluck(:id)
    merger = merger_for({}, users: { 11 => imported.id, 12 => matched.id }, merged_user_ids: [12])

    merger.assign_destination_automatic_groups

    expected =
      Group.desired_trust_level_groups(2) +
        [Group::AUTO_GROUPS[:admins], Group::AUTO_GROUPS[:staff]]
    expect(imported.groups.where(automatic: true).pluck(:id)).to match_array(expected)
    expect(matched.groups.pluck(:id)).to match_array(matched_groups)
    expect(matched.reload.admin).to eq(false)
    expect(matched.trust_level).to eq(0)
  end

  it "verifies PM participants and rejects access added for an unrelated account" do
    recipient = Fabricate(:user)
    unrelated = Fabricate(:user)
    topic = Fabricate(:private_message_topic, user: user, recipient: recipient)
    discussion = Fabricate(:topic)
    TopicAllowedUser.create!(topic: discussion, user: unrelated)
    tables = {
      "topic_allowed_users" => [
        { "topic_id" => "21", "user_id" => "11" },
        { "topic_id" => "21", "user_id" => "12" },
      ],
    }
    importer =
      merger_for(
        tables,
        users: {
          11 => user.id,
          12 => recipient.id,
        },
        groups: {
        },
        topics: {
          21 => topic.id,
          22 => discussion.id,
        },
        category_keys: {
        },
      )
    plan =
      BulkImport::DiscourseMerge::Plan.new(
        {
          "format_version" => 1,
          "categories" => [],
          "topics" => [
            { "source_topic_id" => 21, "action" => "copy_private_message" },
            { "source_topic_id" => 22, "action" => "copy_discussion" },
          ],
        },
      )
    Dir.mktmpdir do |directory|
      verifier = BulkImport::DiscourseMerge::Verifier.new(importer, plan, Pathname.new(directory))
      expect { verifier.verify_access }.not_to raise_error
      expect(Guardian.new(unrelated).can_see?(topic)).to eq(false)
      TopicAllowedUser.create!(topic: topic, user: unrelated)
      expect { verifier.verify_access }.to raise_error(
        BulkImport::DiscourseMerge::Error,
        /topic_allowed_users_participants/,
      )
    end
  end

  it "copies solved associations and acceptance dates without invoking callbacks" do
    definitions = {
      "SolvedTopic" => "topic_id bigint, topic_timer_id bigint",
      "TopicAnswer" => "solved_topic_id bigint, answer_post_id bigint, accepter_user_id bigint",
      "SharedIssue" => "topic_id bigint, user_id bigint",
    }
    definitions.each do |name, columns|
      table = "merge_test_#{name.underscore.pluralize}"
      ActiveRecord::Base.connection.execute(
        "CREATE TEMPORARY TABLE #{table} (id bigserial PRIMARY KEY, #{columns}, created_at timestamp, updated_at timestamp) ON COMMIT DROP",
      )
      model =
        Class.new(ActiveRecord::Base) do
          self.table_name = table
          before_create { raise "Import must bypass callbacks" }
        end
      RSpec::Mocks::ConstantMutator.stub("DiscourseSolved::#{name}", model)
    end
    timestamp = "2024-01-02 03:04:05"
    common = { "created_at" => timestamp, "updated_at" => timestamp }
    tables = {
      "merge_test_solved_topics" => [
        common.merge("id" => "1", "topic_id" => "21", "topic_timer_id" => "31"),
        common.merge("id" => "9", "topic_id" => "999"),
      ],
      "merge_test_topic_answers" => [
        common.merge(
          "id" => "2",
          "solved_topic_id" => "1",
          "answer_post_id" => "41",
          "accepter_user_id" => "11",
        ),
        common.merge("id" => "8", "solved_topic_id" => "9"),
      ],
      "merge_test_shared_issues" => [
        common.merge("id" => "3", "topic_id" => "21", "user_id" => "11"),
      ],
    }
    merger =
      merger_for(
        tables,
        topics: {
          21 => 121,
        },
        posts: {
          41 => 141,
        },
        topic_timers: {
          31 => 131,
        },
        solved_topics: {
        },
        topic_answers: {
        },
        shared_issues: {
        },
      )

    merger.copy_solved

    solved = DiscourseSolved::SolvedTopic.find(merger.maps.fetch(:solved_topics).fetch(1))
    expect(solved.topic_id).to eq(121)
    expect(solved.topic_timer_id).to eq(131)
    answer = DiscourseSolved::TopicAnswer.find(merger.maps.fetch(:topic_answers).fetch(2))
    expect(answer.solved_topic_id).to eq(solved.id)
    expect(answer.answer_post_id).to eq(141)
    expect(answer.accepter_user_id).to eq(user.id)
    expect(answer.created_at).to eq_time(Time.zone.parse(timestamp))
    expect(DiscourseSolved::SharedIssue.first.user_id).to eq(user.id)
    expect(DiscourseSolved::SolvedTopic.count).to eq(1)
  end

  it "verifies a withdrawn like and its original deletion date" do
    like = Fabricate(:post_action, user: user)
    deleted_at = Time.zone.parse("2025-02-03 04:05:06")
    like.update_columns(deleted_at: deleted_at)
    importer =
      merger_for(
        {
          "post_actions" => [
            {
              "id" => "52",
              "post_id" => "41",
              "user_id" => "11",
              "deleted_at" => deleted_at.iso8601,
            },
          ],
        },
        posts: {
          41 => like.post_id,
        },
        post_actions: {
          52 => like.id,
        },
        category_keys: {
        },
      )
    plan =
      BulkImport::DiscourseMerge::Plan.new(
        { "format_version" => 1, "categories" => [], "topics" => [] },
      )

    Dir.mktmpdir do |directory|
      verifier = BulkImport::DiscourseMerge::Verifier.new(importer, plan, Pathname.new(directory))
      expect { verifier.verify_likes }.not_to raise_error
      like.update_columns(deleted_at: nil)
      expect { verifier.verify_likes }.to raise_error(
        BulkImport::DiscourseMerge::Error,
        /like_52_preserved/,
      )
    end
  end

  it "rebuilds search from the imported username, searchable fields, and final category name" do
    imported = Fabricate(:user, username: "harbor_2")
    field = Fabricate(:user_field, searchable: true)
    UserCustomField.create!(user: imported, name: "user_field_#{field.id}", value: "shipwright")
    category = Fabricate(:category, name: "Dockyard")
    post = Fabricate(:post, topic: Fabricate(:topic, category: category))
    UserSearchData.where(user_id: imported.id).delete_all
    CategorySearchData.where(category_id: category.id).delete_all
    plan =
      BulkImport::DiscourseMerge::Plan.new(
        "format_version" => 1,
        "topics" => [],
        "categories" => [{ "key" => "harbor", "operation" => "retain_source" }],
      )
    merger =
      merger_for(
        {},
        plan: plan,
        posts: {
          41 => post.id,
        },
        generated_posts: [],
        category_keys: {
          "harbor" => category.id,
        },
        configuration:
          instance_double(BulkImport::DiscourseMerge::Configuration, preserve_remote?: true),
        users: {
          1 => imported.id,
        },
        first_new_user_id: imported.id,
      )

    SearchIndexer.with_indexing { merger.recook_imported_posts }

    expect(UserSearchData.find_by!(user_id: imported.id).search_data).to include(
      "harbor",
      "shipwright",
    )
    expect(CategorySearchData.find_by!(category_id: category.id).search_data).to include("dockyard")
    expect(PostSearchData.find_by!(post_id: post.id).version).to eq(
      SearchIndexer::POST_INDEX_VERSION,
    )
  end

  it "keeps rewritten optimized image HTML while indexing remote posts" do
    post = Fabricate(:post)
    cooked = '<p><img src="https://pynq.example/optimized/123.png"></p>'
    post.update_columns(cooked: cooked)
    plan =
      BulkImport::DiscourseMerge::Plan.new(
        { "format_version" => 1, "categories" => [], "topics" => [] },
      )
    importer =
      merger_for(
        {},
        configuration:
          instance_double(BulkImport::DiscourseMerge::Configuration, preserve_remote?: true),
        generated_posts: [],
        first_new_user_id: user.id + 1,
        posts: {
          41 => post.id,
        },
        plan: plan,
      )

    importer.recook_imported_posts

    expect(post.reload.cooked).to eq(cooked)
  end
end
