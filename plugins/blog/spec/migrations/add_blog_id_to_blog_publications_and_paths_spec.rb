# frozen_string_literal: true

require Rails.root.join(
          "plugins/blog/db/migrate/20261118184323_add_blog_id_to_blog_publications_and_paths.rb",
        )

RSpec.describe AddBlogIdToBlogPublicationsAndPaths do
  fab!(:publication) { Blog::Publication.create!(topic: Fabricate(:topic), path: "/story") }

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    publication.paths.create!(path: "/story")

    # The test schema already has the columns, so recreate the schema from before.
    DB.exec("ALTER TABLE blog_publications DROP COLUMN blog_id")
    DB.exec("ALTER TABLE blog_paths DROP COLUMN blog_id")
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def blog_ids(table)
    DB.query_single("SELECT DISTINCT blog_id FROM #{table}")
  end

  it "assigns existing articles and their paths to the default blog" do
    described_class.new.up

    default_blog_id = DB.query_single("SELECT id FROM blog_instances WHERE is_default").first
    expect(blog_ids(:blog_publications)).to eq([default_blog_id])
    expect(blog_ids(:blog_paths)).to eq([default_blog_id])
  end

  it "creates the default blog on a site that upgrades past the blogs table in one deploy" do
    DB.exec("DELETE FROM blog_instances")

    described_class.new.up

    default_blog_id =
      DB.query_single("SELECT id FROM blog_instances WHERE is_default AND slug = 'blog'")
    expect(default_blog_id).to be_present
    expect(blog_ids(:blog_publications)).to eq(default_blog_id)
    expect(blog_ids(:blog_paths)).to eq(default_blog_id)
  end
end
