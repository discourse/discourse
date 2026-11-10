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
    publication.update_columns(cooked: nil, image_url: nil, discussion_post_version: nil)
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "takes the discussion post's current HTML while it still carries the published text" do
    discussion_post.update_columns(cooked: "<p>Rebaked on the new host.</p>")

    described_class.new.up

    expect(publication.reload).to have_attributes(
      cooked: "<p>Rebaked on the new host.</p>",
      image_url: "",
      discussion_post_version: discussion_post.version,
    )
  end

  it "keeps the revision snapshot and stops following a discussion post that was edited" do
    discussion_post.update_columns(raw: "An edit made outside a publish.", cooked: "<p>Edited.</p>")

    described_class.new.up

    expect(publication.reload).to have_attributes(
      cooked: publication.published_revision.cooked,
      discussion_post_version: nil,
    )
  end
end
