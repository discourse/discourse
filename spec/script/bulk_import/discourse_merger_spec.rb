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
  end
end
