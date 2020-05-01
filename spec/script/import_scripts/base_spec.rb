# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../script/import_scripts/base'

describe ImportScripts::Base do
  before do
    STDOUT.stubs(:write)
  end

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
      create_users(users) do |row|
        { email: row[:email], id: row[:id] }
      end
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
      create_bookmarks(bookmarks) do |row|
        { post_id: row[:post_id], user_id: row[:user_id] }
      end
    end
  end

  let(:import_data) do
    import_file = Rack::Test::UploadedFile.new(file_from_fixtures("base-import-data.json", "json"))
    ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(import_file.read))
  end

  it "creates bookmarks, posts, and users" do
    MockSpecImporter.new(import_data).perform
    expect(Bookmark.count).to eq(5)
    expect(Post.count).to eq(5)
    expect(User.where('id > 0').count).to eq(1)
  end
end
