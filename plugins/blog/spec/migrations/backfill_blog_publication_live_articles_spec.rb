# frozen_string_literal: true

require Rails.root.join(
          "plugins/blog/db/post_migrate/20261110093228_backfill_blog_publication_live_articles.rb",
        )

RSpec.describe BackfillBlogPublicationLiveArticles do
  include_context "with blog editorial setup"

  fab!(:topic) { Fabricate(:topic, category: drafts, user: writer) }
  fab!(:first_post) do
    Fabricate(
      :post,
      topic:,
      user: writer,
      raw: "Read the guide at https://old.example.com/guide today.",
    )
  end

  let(:discussion_post) { publication.discussion_topic.first_post }

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    publish_blog_draft(publication, acting_user)
    publication.update_columns(cooked: nil, image_url: nil)
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "takes the discussion post's HTML, which already has any earlier hostname remap" do
    DbHelper.remap("old.example.com", "new.example.com")

    described_class.new.up

    expect(publication.reload).to have_attributes(
      cooked: include("https://new.example.com/guide"),
      image_url: "",
    )
  end

  it "keeps the revision snapshot when the discussion post is gone" do
    discussion_post.trash!

    described_class.new.up

    expect(publication.reload.cooked).to eq(publication.published_revision.cooked)
  end
end
