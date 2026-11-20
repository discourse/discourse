# frozen_string_literal: true

require Rails.root.join(
          "plugins/blog/db/post_migrate/20261110093228_backfill_blog_publication_live_articles.rb",
        )

RSpec.describe BackfillBlogPublicationLiveArticles do
  include_context "with blog editorial setup"

  fab!(:topic) { Fabricate(:topic, category: drafts, user: writer) }
  fab!(:first_post) { Fabricate(:post, topic:, user: writer) }

  let(:discussion_post) { publication.discussion_topic.first_post }

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    publish_blog_draft(publication, acting_user)
    publication.update_columns(cooked: nil, image_url: nil)
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "copies the approved snapshot, not a discussion post re-rendered after publishing" do
    discussion_post.update_columns(cooked: "<p>A onebox refetched after approval.</p>")

    described_class.new.up

    expect(publication.reload).to have_attributes(
      cooked: publication.published_revision.cooked,
      image_url: publication.published_revision.data["image_url"],
    )
  end
end
