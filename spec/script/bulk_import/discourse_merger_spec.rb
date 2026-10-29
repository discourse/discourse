# frozen_string_literal: true

merger_dependencies_available =
  begin
    require "redcarpet"
    true
  rescue LoadError
    false
  end

if merger_dependencies_available
  require_relative "../../../script/bulk_import/discourse_merger"

  RSpec.describe BulkImport::DiscourseMerger do
    # The constructor opens raw PG connections to a source and destination
    # database, so specs build an instance without it and set only the state
    # the method under test reads.
    def build_merger(**ivars)
      described_class.allocate.tap do |merger|
        ivars.each { |name, value| merger.instance_variable_set(:"@#{name}", value) }
      end
    end

    it "does not start a merge when the script is merely required" do
      expect(described_class).to respond_to(:new)
    end

    describe "#fix_category_descriptions" do
      fab!(:category)
      fab!(:old_description_topic, :topic)
      fab!(:new_description_topic, :topic)

      let(:merger) do
        build_merger(
          categories: {
            999_999 => category.id,
          },
          topics: {
            old_description_topic.id => new_description_topic.id,
          },
        )
      end

      before do
        category.update_columns(topic_id: old_description_topic.id)
        category.custom_fields["import_id"] = "999999"
        category.save_custom_fields
      end

      it "remaps the description topic of merged categories" do
        merger.fix_category_descriptions

        expect(category.reload.topic_id).to eq(new_description_topic.id)
      end

      it "remaps categories whose copied attributes no longer pass validation" do
        category.update_columns(color: "zzzzzz")

        merger.fix_category_descriptions

        expect(category.reload.topic_id).to eq(new_description_topic.id)
      end
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

    describe "#fix_user_upload" do
      fab!(:merged_user, :user)
      fab!(:old_upload, :upload)
      fab!(:new_upload, :upload)

      let(:merger) { build_merger(first_new_user_id: merged_user.id) }

      before do
        merged_user.update_columns(uploaded_avatar_id: old_upload.id)
        allow(merger).to receive(:upload_id_from_imported_id).with(old_upload.id).and_return(
          new_upload.id,
        )
      end

      it "remaps the avatar of merged users whose copied attributes no longer pass validation" do
        merged_user.primary_email.delete

        merger.fix_user_upload

        expect(merged_user.reload.uploaded_avatar_id).to eq(new_upload.id)
      end
    end

    describe "#remap_upload_reference_target" do
      let(:merger) { build_merger }

      before do
        allow(merger).to receive(:user_id_from_imported_id).with("1").and_return(101)
        allow(merger).to receive(:avatar_id_from_imported_id).with("1").and_return(201)
        allow(merger).to receive(:post_id_from_imported_id).with("1").and_return(301)
        allow(merger).to receive(:post_id_from_imported_id).with("2").and_return(nil)
      end

      def remap(target_type, target_id = "1")
        merger.send(
          :remap_upload_reference_target,
          { "target_type" => target_type, "target_id" => target_id },
        )
      end

      it "remaps each target type through its own mapping" do
        expect(remap("UserProfile")).to eq("target_type" => "UserProfile", "target_id" => 101)
        expect(remap("User")).to eq("target_type" => "User", "target_id" => 101)
        expect(remap("UserAvatar")).to eq("target_type" => "UserAvatar", "target_id" => 201)
        expect(remap("Post")).to eq("target_type" => "Post", "target_id" => 301)
      end

      it "skips references whose target was not copied" do
        expect(remap("Post", "2")).to be_nil
      end

      it "skips unsupported target types" do
        expect(remap("Category")).to be_nil
      end
    end

    def source_returning(rows)
      instance_double(PG::Connection, exec: rows)
    end

    describe "#merge_same_named_rows" do
      fab!(:destination_group) { Fabricate(:group, name: "support_team") }
      fab!(:other_group, :group)

      it "maps same-named source rows onto the destination row and excludes them from the copy" do
        groups = {}
        merger = build_merger(groups:)
        allow(merger).to receive(:source_raw_connection).and_return(
          source_returning([{ "id" => other_group.id.to_s, "name" => "Support_Team" }]),
        )

        sql = merger.merge_same_named_rows(Group, groups, where: "automatic = false")

        expect(groups).to eq(other_group.id => destination_group.id)
        copied_ids = DB.query_single(sql.sub(/\ASELECT .* FROM/, "SELECT id FROM"))
        expect(copied_ids).to include(destination_group.id)
        expect(copied_ids).not_to include(other_group.id)
        expect(copied_ids).not_to include(*Group::AUTO_GROUPS.values)
      end

      it "selects every row when no names collide" do
        tag_group = Fabricate(:tag_group, name: "Staff only")
        tag_groups = {}
        merger = build_merger(tag_groups:)
        allow(merger).to receive(:source_raw_connection).and_return(
          source_returning([{ "id" => "42", "name" => "Something else" }]),
        )

        sql = merger.merge_same_named_rows(TagGroup, tag_groups)

        expect(tag_groups).to be_empty
        expect(DB.query_single(sql.sub(/\ASELECT .* FROM/, "SELECT id FROM"))).to eq([tag_group.id])
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

      let(:merger) { build_merger }

      def expect_guard(method, existing:, other:)
        expect(merger.public_send(method, existing.stringify_keys)).to be_nil
        expect(merger.public_send(method, other.stringify_keys)).to eq(other.stringify_keys)
      end

      it "skips tag group memberships the destination already has" do
        TagGroupMembership.create!(tag_group:, tag:)

        expect_guard(
          :process_tag_group_membership,
          existing: {
            tag_group_id: tag_group.id,
            tag_id: tag.id,
          },
          other: {
            tag_group_id: tag_group.id,
            tag_id: other_tag.id,
          },
        )
      end

      it "skips category tag groups the destination already has" do
        CategoryTagGroup.create!(category:, tag_group:)

        expect_guard(
          :process_category_tag_group,
          existing: {
            category_id: category.id,
            tag_group_id: tag_group.id,
          },
          other: {
            category_id: other_category.id,
            tag_group_id: tag_group.id,
          },
        )
      end

      it "skips category required tag groups the destination already has" do
        CategoryRequiredTagGroup.create!(category:, tag_group:, min_count: 1)

        expect_guard(
          :process_category_required_tag_group,
          existing: {
            category_id: category.id,
            tag_group_id: tag_group.id,
          },
          other: {
            category_id: category.id,
            tag_group_id: other_tag_group.id,
          },
        )
      end

      it "skips tag group permissions the destination already has" do
        TagGroupPermission.create!(tag_group:, group:, permission_type: 1)

        expect_guard(
          :process_tag_group_permission,
          existing: {
            tag_group_id: tag_group.id,
            group_id: group.id,
          },
          other: {
            tag_group_id: other_tag_group.id,
            group_id: group.id,
          },
        )
      end

      it "skips group tag notification defaults the destination already has" do
        GroupTagNotificationDefault.create!(group:, tag:, notification_level: 1)

        expect_guard(
          :process_group_tag_notification_default,
          existing: {
            group_id: group.id,
            tag_id: tag.id,
          },
          other: {
            group_id: group.id,
            tag_id: other_tag.id,
          },
        )
      end

      it "skips group category notification defaults the destination already has" do
        GroupCategoryNotificationDefault.create!(group:, category:, notification_level: 1)

        expect_guard(
          :process_group_category_notification_default,
          existing: {
            group_id: group.id,
            category_id: category.id,
          },
          other: {
            group_id: group.id,
            category_id: other_category.id,
          },
        )
      end

      it "skips muted users the destination already has" do
        MutedUser.create!(user:, muted_user: other_user)

        expect_guard(
          :process_muted_user,
          existing: {
            user_id: user.id,
            muted_user_id: other_user.id,
          },
          other: {
            user_id: other_user.id,
            muted_user_id: user.id,
          },
        )
      end

      it "skips ignored users the destination already has" do
        IgnoredUser.create!(user:, ignored_user: other_user, expiring_at: 1.month.from_now)

        expect_guard(
          :process_ignored_user,
          existing: {
            user_id: user.id,
            ignored_user_id: other_user.id,
          },
          other: {
            user_id: other_user.id,
            ignored_user_id: user.id,
          },
        )
      end

      it "skips user uploads the destination already has" do
        UserUpload.create!(upload:, user:)

        expect_guard(
          :process_user_upload,
          existing: {
            upload_id: upload.id,
            user_id: user.id,
          },
          other: {
            upload_id: upload.id,
            user_id: other_user.id,
          },
        )
      end

      it "skips category users the destination already has" do
        CategoryUser.create!(category:, user:, notification_level: 1)

        expect_guard(
          :process_category_user,
          existing: {
            category_id: category.id,
            user_id: user.id,
          },
          other: {
            category_id: other_category.id,
            user_id: user.id,
          },
        )
      end

      it "skips upload references the destination already has" do
        UploadReference.create!(upload:, target: post)

        expect_guard(
          :process_upload_reference,
          existing: {
            upload_id: upload.id,
            target_type: "Post",
            target_id: post.id,
          },
          other: {
            upload_id: upload.id,
            target_type: "User",
            target_id: post.id,
          },
        )
      end

      it "skips category search data the destination already has" do
        CategorySearchData.where(category_id: category.id).delete_all
        CategorySearchData.create!(category_id: category.id, search_data: "existing")
        CategorySearchData.where(category_id: other_category.id).delete_all

        expect_guard(
          :process_category_search_data,
          existing: {
            category_id: category.id,
          },
          other: {
            category_id: other_category.id,
          },
        )
      end
    end

    describe "#copy_uploads" do
      fab!(:user)
      fab!(:existing_upload) { Fabricate(:upload, user:) }

      let(:copied_rows) { [] }
      let(:destination_connection) do
        rows = copied_rows
        Class
          .new do
            define_method(:copy_data) { |_sql, _encoder, &block| block.call }
            define_method(:put_copy_data) { |values| rows << values }
          end
          .new
      end

      def upload_row(upload, id:, sha1:)
        Upload
          .columns
          .map(&:name)
          .index_with { |column| upload.read_attribute_before_type_cast(column)&.to_s }
          .merge("id" => id.to_s, "sha1" => sha1)
      end

      it "maps source uploads that already exist in the destination onto the existing upload" do
        uploads = {}
        merger =
          build_merger(
            raw_connection: destination_connection,
            encoder: nil,
            uploads:,
            users: {
              user.id => user.id,
            },
            sequences: {
            },
            uploads_path: "/nonexistent",
          )
        allow(FileUtils).to receive(:cp_r)
        allow(merger).to receive(:source_raw_connection).and_return(
          source_returning(
            [
              upload_row(existing_upload, id: 500, sha1: existing_upload.sha1),
              upload_row(existing_upload, id: 501, sha1: "new-sha1"),
            ],
          ),
        )

        merger.copy_uploads

        expect(uploads["500"]).to eq(existing_upload.id)
        expect(uploads["501"]).to be > existing_upload.id
        expect(copied_rows.map { |values| values[Upload.column_names.index("sha1")] }).to eq(
          ["new-sha1"],
        )
      end
    end
  end
end
