# frozen_string_literal: true

module ::Blog
  class Revision < ActiveRecord::Base
    self.table_name = "blog_revisions"
    belongs_to :publication
    belongs_to :source_topic, class_name: "Topic"
    belongs_to :creator, class_name: "User"
    belongs_to :approver, class_name: "User", optional: true
    has_many :upload_references, as: :target, dependent: :destroy
    after_create :retain_uploads
    attr_readonly :data, :publication_id, :source_topic_id, :creator_id

    def self.capture(publication, source)
      post = source.first_post
      metadata = publication.editorial_metadata
      upload = source.image_upload
      metadata.merge(
        "title" => source.title,
        "raw" => post.raw,
        "cooked" => post.cooked,
        "author_name" => source.user&.name.presence || source.user&.username,
        "image_url" => upload && !upload.secure? ? upload.url : "",
        "tags" => source.tags.visible(Guardian.new).pluck(:name),
      )
    end

    def title
      data["title"]
    end

    def cooked
      data["cooked"]
    end

    def reading_minutes
      [(PrettyText.excerpt(cooked.to_s, 100_000, strip_tags: true).split.size / 220.0).ceil, 1].max
    end

    def raw
      data["raw"]
    end

    private

    def retain_uploads
      UploadReference.ensure_exist!(upload_ids: Upload.extract_upload_ids(raw), target: self)
    end
  end
end

# == Schema Information
#
# Table name: blog_revisions
#
#  id              :bigint           not null, primary key
#  approved_at     :datetime
#  data            :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  approver_id     :bigint
#  creator_id      :bigint           not null
#  publication_id  :bigint           not null
#  source_topic_id :bigint           not null
#
# Indexes
#
#  index_blog_revisions_on_publication_id_and_id  (publication_id,id)
#
