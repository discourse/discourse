# frozen_string_literal: true

require_relative "../../../script/import_scripts/base"

RSpec.describe ImportScripts::Base do
  before { STDOUT.stubs(:write) }

  class MockSpecImporter < ImportScripts::Base
    def initialize(data)
      super()
      @import_data = data
    end

    def execute
      import_users
      import_posts
      import_bookmarks
    end

    def import_users
      users = @import_data[:users]
      create_users(users) { |row| { email: row[:email], id: row[:id] } }
    end

    def import_posts
      posts = @import_data[:posts]
      create_posts(posts) do |row|
        user_id = @lookup.user_id_from_imported_user_id(row[:user_id]) || -1
        { user_id: user_id, raw: row[:raw], id: row[:id], title: "Test topic for post #{row[:id]}" }
      end
    end

    def import_bookmarks
      bookmarks = @import_data[:bookmarks]
      create_bookmarks(bookmarks) { |row| { post_id: row[:post_id], user_id: row[:user_id] } }
    end
  end

  let(:import_data) do
    import_file = Rack::Test::UploadedFile.new(file_from_fixtures("base-import-data.json", "json"))
    ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(import_file.read))
  end

  it "creates bookmarks, posts, and users" do
    MockSpecImporter.new(import_data).perform
    expect(Bookmark.where(bookmarkable_type: "Post").count).to eq(5)
    expect(Post.count).to eq(5)
    expect(User.where("id > 0").count).to eq(1)
    expect(SiteSetting.purge_unactivated_users_grace_period_days).to eq(60)
  end

  it "does not change purge unactivated users setting if disabled" do
    SiteSetting.purge_unactivated_users_grace_period_days = 0
    MockSpecImporter.new(import_data).perform
    expect(SiteSetting.purge_unactivated_users_grace_period_days).to eq(0)
  end

  describe "#create_post" do
    let(:importer) { described_class.new }
    fab!(:user) { Fabricate(:user) }
    let(:post_params) {
      {
        user_id: user.id,
        raw: "Test post [b]content[/b]",
        title: "Test topic for post"
      }
    }

    it "creates a Post" do
      expect {
        importer.create_post(post_params, 123)
      }.to change { Post.count }.by(1)
    end

    if ENV["IMPORT"] == "1"
      it "uses the ruby-bbcode-to-md gem (conditional Gemfile option)" do
        expect(String.method_defined?(:bbcode_to_md)).to be true
      end

      it "converts bbcode to markdown when specified" do
        importer.instance_variable_set(:@bbcode_to_md, true)
        importer.create_post(post_params, 123)
        expect(Post.first.raw).to eq "Test post **content**"
      end
    end
  end
end
