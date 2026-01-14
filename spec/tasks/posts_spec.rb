# frozen_string_literal: true

require "highline/import"
require "highline/simulate"

RSpec.describe "Post rake tasks" do
  fab!(:post) { Fabricate(:post, raw: "The quick brown fox jumps over the lazy dog") }
  fab!(:tricky_post) { Fabricate(:post, raw: "Today ^Today") }

  before { STDOUT.stubs(:write) }

  describe "remap" do
    it "should remap posts" do
      HighLine::Simulate.with("y") { invoke_rake_task("posts:remap", "brown", "red") }

      post.reload
      expect(post.raw).to eq("The quick red fox jumps over the lazy dog")
    end

    context "when type == string" do
      it "remaps input as string" do
        HighLine::Simulate.with("y") do
          invoke_rake_task("posts:remap", "^Today", "Yesterday", "string")
        end

        expect(tricky_post.reload.raw).to eq("Today Yesterday")
      end
    end

    context "when type == regex" do
      it "remaps input as regex" do
        HighLine::Simulate.with("y") do
          invoke_rake_task("posts:remap", "^Today", "Yesterday", "regex")
        end

        expect(tricky_post.reload.raw).to eq("Yesterday ^Today")
      end
    end
  end

  describe "rebake_match" do
    it "rebakes matched posts" do
      post.update(cooked: "")

      HighLine::Simulate.with("y") { invoke_rake_task("posts:rebake_match", "brown") }

      expect(post.reload.cooked).to eq("<p>The quick brown fox jumps over the lazy dog</p>")
    end
  end

  describe "missing_uploads" do
    let(:url) do
      "/uploads/#{RailsMultisite::ConnectionManagement.current_db}/original/1X/d1c2d40ab994e8410c.png"
    end
    let(:upload) { Fabricate(:upload, url: url) }

    it "should create post custom field for missing upload" do
      post = Fabricate(:post, raw: "A sample post <img src='#{url}'>")
      upload.destroy!

      invoke_rake_task("posts:missing_uploads")

      post.reload
      expect(post.custom_fields[Post::MISSING_UPLOADS]).to eq([url])
    end

    it 'should skip all the posts with "ignored" custom field' do
      post = Fabricate(:post, raw: "A sample post <img src='#{url}'>")
      post.custom_fields[Post::MISSING_UPLOADS_IGNORED] = true
      post.save_custom_fields
      upload.destroy!

      invoke_rake_task("posts:missing_uploads")

      post.reload
      expect(post.custom_fields[Post::MISSING_UPLOADS]).to be_nil
    end
  end

  describe "posts:reorder_posts" do
    fab!(:topic)

    fab!(:p1) { Fabricate(:post, topic: topic, created_at: 1.day.ago, post_number: 5) }
    fab!(:p2) { Fabricate(:post, topic: topic, created_at: 2.days.ago, post_number: 1) }
    fab!(:p3) { Fabricate(:post, topic: topic, created_at: 3.days.ago, post_number: 3) }

    # PostTimings pointing at existing posts
    fab!(:pt1) do
      PostTiming.create!(topic_id: topic.id, post_number: p1.post_number, user_id: -2, msecs: 111)
    end
    fab!(:pt2) do
      PostTiming.create!(topic_id: topic.id, post_number: p2.post_number, user_id: -2, msecs: 222)
    end
    fab!(:pt3) do
      PostTiming.create!(topic_id: topic.id, post_number: p3.post_number, user_id: -2, msecs: 333)
    end

    # Orphaned PostTiming (no post with this post_number exists in topic)
    # This orphaned PostTiming will cause duplicate key errors if not taken
    # into account when the rake task is run
    fab!(:pt_orphan) do
      PostTiming.create!(topic_id: topic.id, post_number: 2, user_id: -2, msecs: 999)
    end

    it "reorders posts and fixes orphaned PostTimings" do
      invoke_rake_task("posts:reorder_posts")

      expect(topic.posts.order(:created_at).pluck(:post_number)).to eq([1, 2, 3])

      # Orphaned PostTiming should have been negated
      pt_orphan_updated = PostTiming.find_by(topic_id: topic.id, user_id: -2, post_number: -2)
      expect(pt_orphan_updated).to be_present

      p1.reload
      p2.reload
      p3.reload

      pt1_updated = PostTiming.find_by(topic_id: topic.id, user_id: -2, post_number: p1.post_number)
      pt2_updated = PostTiming.find_by(topic_id: topic.id, user_id: -2, post_number: p2.post_number)
      pt3_updated = PostTiming.find_by(topic_id: topic.id, user_id: -2, post_number: p3.post_number)

      expect(pt1_updated).to be_present
      expect(pt2_updated).to be_present
      expect(pt3_updated).to be_present
    end
  end
end
