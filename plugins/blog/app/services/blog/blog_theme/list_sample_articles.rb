# frozen_string_literal: true

# Picks the public articles theme authors can render their templates against.
class Blog::BlogTheme::ListSampleArticles
  include Service::Base

  MAX_SAMPLES = 30

  params { attribute :article_id, :integer }

  policy :can_manage_themes
  model :publications, optional: true
  model :publication, optional: true
  policy :requested_article_is_sample

  private

  def can_manage_themes(guardian:)
    guardian.is_admin?
  end

  def fetch_publications
    Blog::Publication
      .publicly_visible
      .newest
      .limit(MAX_SAMPLES)
      .includes(:published_revision, discussion_topic: %i[first_post user image_upload tags])
  end

  # Without an explicit choice, the newest article is the sample.
  def fetch_publication(params:, publications:)
    return publications.first if params.article_id.blank?
    publications.find_by(id: params.article_id)
  end

  def requested_article_is_sample(params:, publication:)
    params.article_id.blank? || publication.present?
  end
end
