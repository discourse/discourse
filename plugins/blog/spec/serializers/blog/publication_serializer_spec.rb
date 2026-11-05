# frozen_string_literal: true

RSpec.describe Blog::PublicationSerializer do
  fab!(:admin)
  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:topic) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:first_post) do
    Fabricate(:post, topic:, user: admin, raw: "An article ready for a careful review.")
  end

  let(:publication) { Blog::Publication.for_topic(topic) }

  before { enable_blog!(category:, drafts:) }

  def serialize(**options)
    described_class.new(publication, scope: admin.guardian, root: false, **options).as_json
  end

  it "names the role of the viewed topic" do
    publish_blog_draft(publication, admin)

    expect(serialize[:role]).to eq("source")
    expect(serialize(viewed_topic: topic)[:role]).to eq("draft")
    expect(serialize(viewed_topic: publication.discussion_topic)[:role]).to eq("discussion")
  end

  it "follows the article through its publishing states" do
    publication.save!
    expect(serialize[:status]).to eq("draft")

    publish_blog_draft(publication, admin)
    expect(serialize[:status]).to eq("live")

    first_post.revise(admin, raw: "A correction to the live article, waiting to go out.")
    publication.reload
    expect(serialize[:status]).to eq("changes_pending")

    unpublish_blog_article(publication, admin)
    expect(serialize[:status]).to eq("unpublished")
  end

  it "reports public visibility unless the caller already knows it" do
    publish_blog_draft(publication, admin)

    expect(serialize[:live]).to eq(true)
    expect(serialize(live: false)[:live]).to eq(false)
  end

  it "describes a scheduled revision" do
    revision = submit_blog_draft(publication, admin)
    approve_blog_revision(publication, revision, admin)
    schedule_blog_revision(publication, revision, admin)

    json = serialize
    expect(json[:status]).to eq("scheduled")
    expect(json[:submitted_revision]).to eq(
      id: revision.id,
      title: topic.title,
      approved_by: admin.username,
      preview_url: "#{publication.preview_url}?revision_id=#{revision.id}",
    )
    expect(json[:scheduled_revision]).to eq(json[:submitted_revision])
  end
end
