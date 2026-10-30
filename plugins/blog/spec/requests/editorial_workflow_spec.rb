# frozen_string_literal: true

RSpec.describe "Blog editorial workflow", type: :request do
  fab!(:admin)
  fab!(:category)
  fab!(:writers, :group)
  fab!(:writer) { Fabricate(:user, groups: [writers], refresh_auto_groups: true) }
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }
  fab!(:topic) { Fabricate(:topic, category: drafts, user: writer) }
  fab!(:first_post) do
    Fabricate(
      :post,
      topic: topic,
      user: writer,
      raw: "An article ready for a careful editorial review.",
    )
  end

  before do
    enable_blog!(category: category, drafts: drafts)
    SiteSetting.blog_contributor_groups = writers.id.to_s
    drafts.set_permissions(:staff => :full, writers.name => :full)
    drafts.save!
  end

  it "requires explicit approval and copies only the frozen article, keeping editorial replies private" do
    note =
      Fabricate(
        :post,
        topic: topic,
        user: admin,
        raw: "Confidential editorial notes must never become public.",
      )
    sign_in(writer)
    post "/blog-editor/publications/#{topic.id}/submit.json"
    expect(response.status).to eq(200)
    revision_id = response.parsed_body.dig("submitted_revision", "id")
    post "/blog-editor/publications/#{topic.id}/approve.json", params: { revision_id: revision_id }
    expect(response.status).to eq(403)
    post "/blog-editor/publications/#{topic.id}/publish.json", params: { revision_id: revision_id }
    expect(response.status).to eq(403)

    sign_in(admin)
    post "/blog-editor/publications/#{topic.id}/publish.json", params: { revision_id: revision_id }
    expect(response.status).to eq(400)
    post "/blog-editor/publications/#{topic.id}/approve.json", params: { revision_id: revision_id }
    expect(response.status).to eq(200)
    first_post.revise(writer, raw: "A newer private edit that has not been submitted or approved.")
    post "/blog-editor/publications/#{topic.id}/publish.json", params: { revision_id: revision_id }
    expect(response.status).to eq(200)

    publication = Blog::Publication.find_by!(topic: topic)
    discussion = publication.discussion_topic
    expect(discussion.id).not_to eq(topic.id)
    expect(discussion.posts.count).to eq(1)
    expect(discussion.first_post.raw).to eq(publication.published_revision.raw)
    expect(discussion.first_post.raw).not_to eq(first_post.reload.raw)
    expect(note.reload.topic_id).to eq(topic.id)
    expect(topic.reload.category_id).to eq(drafts.id)
    expect(admin.guardian.can_edit_post?(discussion.first_post)).to eq(false)
    expect(writer.guardian.can_edit_post?(first_post)).to eq(true)
    get "https://blog.example.com#{publication.path}"
    expect(response.status).to eq(200)
    expect(response.body).not_to include(first_post.raw, note.raw)
  end

  it "preserves existing discussion IDs and replies while staging a private working copy" do
    topic.update_column(:category_id, category.id)
    topic.reload
    publication =
      Blog::Publication.create!(
        topic: topic,
        discussion_topic: topic,
        path: "/existing",
        published: true,
        published_at: 1.day.ago,
      )
    reply = Fabricate(:post, topic: topic, user: writer)
    source = publication.prepare_draft!(admin)
    expect(source.category_id).to eq(drafts.id)
    expect(source.posts.count).to eq(1)
    expect(source.first_post.raw).to eq(first_post.raw)
    source.first_post.revise(
      admin,
      raw: "A carefully revised article that should only go live after approval.",
    )
    publication.save_metadata!(admin, path: "/updated", excerpt: "A staged introduction")
    expect(publication.reload.path).to eq("/existing")
    expect(publication.published_revision.raw).to eq(first_post.raw)
    publication.publish!(admin)
    expect(publication.discussion_topic_id).to eq(topic.id)
    expect(reply.reload.topic_id).to eq(topic.id)
    expect(first_post.reload.raw).to eq(source.first_post.raw)
    expect(publication.path).to eq("/updated")
  end

  it "denies contributors access to someone else's drafts and frozen revisions" do
    other = Fabricate(:topic, category: drafts, user: admin)
    Fabricate(:post, topic: other, user: admin)
    publication = Blog::Publication.for_topic(other)
    revision = publication.submit!(admin)
    sign_in(writer)
    get "/blog-editor/publications/#{other.id}.json"
    expect(response.status).to eq(403)
    get "/blog-editor/preview/#{other.id}", params: { revision_id: revision.id }
    expect(response.status).to eq(403)
    get "/blog-editor.json"
    expect(response.parsed_body["topics"].map { |entry| entry["id"] }).to contain_exactly(topic.id)
  end

  it "previews the submitted snapshot rather than later edits" do
    publication = Blog::Publication.for_topic(topic)
    revision = publication.submit!(admin)
    first_post.revise(
      writer,
      raw: "Later unpublished article content must stay out of the revision preview.",
    )
    sign_in(admin)
    get "/blog-editor/preview/#{topic.id}", params: { revision_id: revision.id }
    expect(response.status).to eq(200)
    expect(response.body).to include(revision.raw)
    expect(response.body).not_to include(first_post.reload.raw)
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "publishes the scheduled approved revision exactly once even after a newer submission" do
    freeze_time
    publication = Blog::Publication.for_topic(topic)
    revision = publication.submit!(admin)
    publication.approve!(admin, revision.id)
    publication.schedule!(admin, revision_id: revision.id, at: 2.hours.from_now.iso8601)
    token = publication.schedule_token
    first_post.revise(
      writer,
      raw: "Another draft for the next editorial round, not this scheduled release.",
    )
    publication.submit!(writer)
    Jobs::PublishBlogRevision.new.execute(publication_id: publication.id, token: token)
    expect(publication.reload).not_to be_published
    freeze_time 3.hours.from_now
    Jobs::PublishBlogRevision.new.execute(publication_id: publication.id, token: token)
    expect(publication.reload.published_revision_id).to eq(revision.id)
    expect(publication.discussion_topic.first_post.raw).to eq(revision.raw)
    expect {
      Jobs::PublishBlogRevision.new.execute(publication_id: publication.id, token: token)
    }.not_to change(Topic, :count)
    expect(publication.scheduled_at).to be_nil
  end

  it "invalidates canceled schedules and fails closed when publisher access is removed" do
    freeze_time
    publication = Blog::Publication.for_topic(topic)
    revision = publication.submit!(admin)
    publication.approve!(admin, revision.id)
    publication.schedule!(admin, revision_id: revision.id, at: 2.hours.from_now.iso8601)
    canceled_token = publication.schedule_token
    publication.cancel_schedule!(admin)
    publication.schedule!(admin, revision_id: revision.id, at: 2.hours.from_now.iso8601)
    token = publication.schedule_token
    freeze_time 3.hours.from_now
    publication.run_schedule!(canceled_token)
    expect(publication.reload).not_to be_published
    admin.update!(suspended_till: 1.day.from_now)
    publication.run_schedule!(token)
    expect(publication.reload).not_to be_published
    expect(publication.scheduled_at).to be_nil
    expect(publication.schedule_error).to be_present
  end

  it "rejects stale approvals and cross-article revision IDs without altering approval provenance" do
    publication = Blog::Publication.for_topic(topic)
    revision = publication.submit!(admin)
    publication.approve!(admin, revision.id)
    approved_at = revision.reload.approved_at
    freeze_time 1.hour.from_now
    publication.approve!(admin, revision.id)
    expect(revision.reload.approved_at).to eq_time(approved_at)
    publication.submit!(admin)
    expect { publication.approve!(admin, revision.id) }.to raise_error(Discourse::InvalidParameters)
    other = Fabricate(:topic, category: drafts, user: admin)
    Fabricate(:post, topic: other, user: admin)
    other_revision = Blog::Publication.for_topic(other).submit!(admin)
    expect { publication.approve!(admin, other_revision.id) }.to raise_error(
      ActiveRecord::RecordNotFound,
    )
  end

  it "prevents even administrators from moving an untracked editorial topic directly into public view" do
    sign_in(admin)
    put "/t/#{topic.id}.json", params: { category_id: category.id }
    expect(response.status).to eq(422)
    expect(topic.reload.category_id).to eq(drafts.id)
    expect(Blog::Publication.where(topic_id: topic.id)).not_to exist
  end

  it "records a scheduled path collision without leaving an expired schedule behind" do
    freeze_time
    publication = Blog::Publication.for_topic(topic)
    publication.save_metadata!(admin, path: "/contested-path")
    revision = publication.submit!(admin)
    publication.approve!(admin, revision.id)
    publication.schedule!(admin, revision_id: revision.id, at: 2.hours.from_now.iso8601)
    token = publication.schedule_token
    other = Fabricate(:topic, category: drafts, user: admin)
    Fabricate(:post, topic: other, user: admin)
    competitor = Blog::Publication.for_topic(other)
    competitor.save_metadata!(admin, path: "/contested-path")
    competitor.publish!(admin)
    freeze_time 3.hours.from_now
    expect { publication.run_schedule!(token) }.not_to change(Topic, :count)
    expect(publication.reload.scheduled_at).to be_nil
    expect(publication.schedule_error).to be_present
    expect(publication).not_to be_published
    expect(competitor.reload).to be_publicly_visible
  end

  it "recovers overdue schedules and rejects invalid scheduling times" do
    freeze_time
    publication = Blog::Publication.for_topic(topic)
    revision = publication.submit!(admin)
    publication.approve!(admin, revision.id)
    ["invalid", 1.minute.ago.iso8601, 2.years.from_now.iso8601].each do |time|
      expect { publication.schedule!(admin, revision_id: revision.id, at: time) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
    publication.schedule!(admin, revision_id: revision.id, at: 2.hours.from_now.iso8601)
    freeze_time 3.hours.from_now
    Jobs::RecoverBlogSchedules.new.execute
    expect_job_enqueued(
      job: :publish_blog_revision,
      args: {
        publication_id: publication.id,
        token: publication.schedule_token,
      },
    )
  end

  it "lets a non-staff publisher self-approve and publish within native category permissions" do
    SiteSetting.blog_publisher_groups = writers.id.to_s
    sign_in(writer)
    post "/blog-editor/publications/#{topic.id}/submit.json"
    expect(response.status).to eq(200)
    revision_id = response.parsed_body.dig("submitted_revision", "id")
    post "/blog-editor/publications/#{topic.id}/approve.json", params: { revision_id: revision_id }
    expect(response.status).to eq(200)
    post "/blog-editor/publications/#{topic.id}/publish.json", params: { revision_id: revision_id }
    expect(response.status).to eq(200)
    publication = Blog::Publication.find_by!(topic: topic)
    expect(publication).to be_publicly_visible
    discussion_id = publication.discussion_topic_id
    first_post.revise(
      writer,
      raw: "A revised article released by a non-staff publisher after approval.",
    )
    publication.publish!(writer)
    expect(publication.discussion_topic_id).to eq(discussion_id)
    expect(publication.discussion_topic.first_post.reload.raw).to eq(first_post.reload.raw)
    expect(writer.reload).not_to be_staff
  end

  it "preserves the publication date when correcting an article from a still-open draft form" do
    publication = Blog::Publication.for_topic(topic)
    publication.publish!(admin)
    original_date = publication.published_at
    discussion_id = publication.discussion_topic_id
    first_post.revise(
      writer,
      raw: "The corrected article text is ready for another approved release.",
    )
    sign_in(admin)
    put "/blog-editor/publications/#{topic.id}.json",
        params: {
          publication: {
            published_at: nil,
          },
        },
        as: :json
    expect(response.status).to eq(200)
    expect(response.parsed_body["published_revision_id"]).to eq(publication.published_revision_id)
    post "/blog-editor/publications/#{topic.id}/submit.json"
    expect(response.status).to eq(200)
    revision_id = response.parsed_body.dig("submitted_revision", "id")
    post "/blog-editor/publications/#{topic.id}/approve.json", params: { revision_id: revision_id }
    expect(response.status).to eq(200)
    post "/blog-editor/publications/#{topic.id}/publish.json", params: { revision_id: revision_id }
    expect(response.status).to eq(200)
    expect(response.parsed_body["published_revision_id"]).to eq(revision_id)
    expect(response.parsed_body["live"]).to eq(true)
    expect(publication.reload.published_at).to eq_time(original_date)
    expect(publication.discussion_topic_id).to eq(discussion_id)
    expect(publication.discussion_topic.first_post.raw).to eq(first_post.reload.raw)
  end

  it "distinguishes a published article from its pending private correction in the editor" do
    publication = Blog::Publication.for_topic(topic)
    publication.publish!(admin)
    original_title = topic.title
    sign_in(admin)
    get "/blog-editor/publications/#{topic.id}.json"
    expect(response.parsed_body["draft_correction"]).to eq(false)
    first_post.revise(writer, raw: "A private correction that has not been published yet.")
    topic.update!(title: "A private correction title for review")
    publication.save_metadata!(admin, excerpt: "A private correction introduction")
    get "/blog-editor.json"
    entry = response.parsed_body["topics"].find { |item| item["id"] == topic.id }
    expect(entry["live"]).to eq(true)
    expect(entry["draft_correction"]).to eq(true)
    expect(entry["public_title"]).to eq(original_title)
    expect(entry["source_url"]).to eq(topic.url)
    expect(entry["discussion_url"]).to eq(publication.discussion_topic.url)
    publication.publish!(admin)
    get "/blog-editor/publications/#{topic.id}.json"
    expect(response.parsed_body["draft_correction"]).to eq(false)
    expect(response.parsed_body["public_title"]).to eq(topic.title)
  end
end
