# frozen_string_literal: true

module BlogSpecHelpers
  BLOG_HOST = "blog.example.com"
  DISCUSSION_HOST = "test.localhost"
  BLOG_HOSTNAMES = [DISCUSSION_HOST, BLOG_HOST].freeze

  # Enables the blog, optionally wiring its categories. A custom domain stubs both
  # hostnames; without one the blog is served under /blog on the forum.
  def enable_blog!(category: nil, drafts: nil, custom_domain: true)
    SiteSetting.blog_enabled = true
    if custom_domain
      RailsMultisite::ConnectionManagement.stubs(:current_db_hostnames).returns(BLOG_HOSTNAMES)
      SiteSetting.blog_url = "https://#{BLOG_HOST}"
    end
    SiteSetting.blog_category = category.id if category
    SiteSetting.blog_drafts_category = drafts.id if drafts
  end

  def create_blog_theme(attributes, user:, source: nil)
    Blog::BlogTheme::Create.call!(
      params: attributes,
      options: {
        source:,
      },
      guardian: user.guardian,
    )[
      :theme
    ]
  end

  # These save an unsaved publication's in-memory changes before running the
  # service, then reload the given record.
  def update_blog_metadata(publication, user, **metadata)
    publication.save! if publication.new_record?
    Blog::Publication::UpdateMetadata.call!(
      params: {
        topic_id: publication.topic_id,
        metadata:,
      },
      guardian: user.guardian,
    )
    publication.reload
  end

  def prepare_blog_draft(publication, user)
    publication.save! if publication.new_record?
    Blog::Publication::PrepareDraft.call!(
      params: {
        topic_id: publication.topic_id,
      },
      guardian: user.guardian,
    )
    publication.reload.editorial_topic
  end

  def submit_blog_draft(publication, user)
    publication.save! if publication.new_record?
    revision =
      Blog::Publication::Submit.call!(
        params: {
          topic_id: publication.topic_id,
        },
        guardian: user.guardian,
      )[
        :revision
      ]
    publication.reload
    revision
  end

  def approve_blog_revision(publication, revision, user)
    Blog::Publication::Approve.call!(
      params: {
        topic_id: publication.topic_id,
        revision_id: revision.id,
      },
      guardian: user.guardian,
    )
    publication.reload
  end

  def publish_blog_draft(publication, user)
    publication.save! if publication.new_record?
    Blog::Publication::Publish.call!(
      params: {
        topic_id: publication.topic_id,
      },
      guardian: user.guardian,
    )
    publication.reload
  end

  def schedule_blog_revision(publication, revision, user, at: 2.hours.from_now)
    Blog::Publication::Schedule.call!(
      params: {
        topic_id: publication.topic_id,
        revision_id: revision.id,
        scheduled_at: at,
      },
      guardian: user.guardian,
    )
    publication.reload
  end

  def run_blog_schedule(publication, token)
    Blog::Publication::RunSchedule.call(params: { publication_id: publication.id, token: })
    publication.reload
  end

  def unpublish_blog_article(publication, user)
    Blog::Publication::Unpublish.call!(
      params: {
        topic_id: publication.topic_id,
      },
      guardian: user.guardian,
    )
    publication.reload
  end

  def activate_blog_theme(theme, user:)
    Blog::BlogTheme::Activate.call!(
      params: {
        theme_id: theme["id"],
        revision: theme["revision"],
      },
      guardian: user.guardian,
    )[
      :active_theme
    ]
  end
end

RSpec.configure { |config| config.include(BlogSpecHelpers) }
