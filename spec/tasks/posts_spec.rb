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
end
