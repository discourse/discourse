# frozen_string_literal: true

RSpec.describe Jobs::PublishBlogRevision do
  fab!(:admin)
  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:topic) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:first_post) do
    Fabricate(
      :post,
      topic: topic,
      user: admin,
      raw: "An article ready for a careful editorial review.",
    )
  end

  before { enable_blog!(category: category, drafts: drafts) }

  describe "#execute" do
    it "keeps a due schedule while the plugin is disabled and publishes it once re-enabled" do
      freeze_time
      publication = Blog::Publication.for_topic(topic)
      revision = publication.submit!(admin)
      publication.approve!(admin, revision.id)
      publication.schedule!(admin, revision_id: revision.id, at: 1.hour.from_now.iso8601)
      token = publication.schedule_token
      freeze_time 2.hours.from_now
      SiteSetting.blog_enabled = false

      described_class.new.execute(publication_id: publication.id, token: token)

      publication.reload
      expect(publication).not_to be_published
      expect(publication.schedule_token).to eq(token)
      expect(publication.schedule_error).to be_blank

      SiteSetting.blog_enabled = true
      Jobs::RecoverBlogSchedules.new.execute
      expect_job_enqueued(
        job: :publish_blog_revision,
        args: {
          publication_id: publication.id,
          token: token,
        },
      )
      described_class.new.execute(publication_id: publication.id, token: token)

      expect(publication.reload.published_revision_id).to eq(revision.id)
    end
  end
end
