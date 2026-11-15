# frozen_string_literal: true

module ::Blog
  class Revision < ActiveRecord::Base
    self.table_name = "blog_revisions"
    # Based on Ghost's reading time (WordPress's default is lower).
    WORDS_PER_MINUTE = 275

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
      cover = Upload.find_by(id: metadata["cover_upload_id"]) if metadata["cover_upload_id"]
      metadata.merge(
        "title" => source.title,
        "raw" => post.raw,
        "cooked" => post.cooked,
        "author_name" => author_name(source.user),
        "co_authors" => co_author_credits(metadata["co_author_ids"]),
        # An explicit cover is also the card and social image.
        "image_url" => image_url_for(cover || source.image_upload),
        "cover_upload_id" => cover&.id,
        "cover_width" => cover&.width,
        "cover_height" => cover&.height,
        "tags" => source.tags.visible(Guardian.new).pluck(:name),
      )
    end

    def self.author_name(user)
      user&.name.presence || user&.username
    end

    # Names are kept as they were at publishing, like the main author's.
    def self.co_author_credits(ids)
      users = User.where(id: ids).index_by(&:id)
      Array(ids).filter_map do |id|
        user = users[id]
        { "user_id" => id, "name" => author_name(user) } if user
      end
    end

    def self.author_path(user)
      "/author/#{user.encoded_username(lower: true)}"
    end

    def self.image_url_for(upload)
      upload && !upload.secure? ? upload.url : ""
    end

    def self.word_count(cooked)
      PrettyText.excerpt(cooked.to_s, 100_000, strip_tags: true).split.size
    end

    def title
      data["title"]
    end

    def co_author_ids
      Array(data["co_authors"]).pluck("user_id")
    end

    # The owner first, then co-authors, as [user, name] pairs. Articles imported without
    # a known author belong to the system user, which isn't credited.
    def authors(owner, users: nil)
      users ||= User.where(id: co_author_ids).index_by(&:id)
      co_authors =
        Array(data["co_authors"]).map { |credit| [users[credit["user_id"]], credit["name"]] }
      [[owner, data["author_name"]], *co_authors].select { |user, _| user&.human? }
    end

    def cooked
      data["cooked"]
    end

    def reading_minutes
      words = data["word_count"] || Revision.word_count(cooked)
      [(words.to_f / WORDS_PER_MINUTE).round, 1].max
    end

    def raw
      data["raw"]
    end

    def public_tags
      Tag.visible(Guardian.new).where(name: data["tags"])
    end

    def absolute_image_url
      url = data["image_url"]
      UrlHelper.absolute(url) if url.present?
    end

    def cover?
      data["cover_upload_id"].present? && data["image_url"].present?
    end

    private

    def retain_uploads
      UploadReference.ensure_exist!(
        upload_ids: [*Upload.extract_upload_ids(raw), data["cover_upload_id"]],
        target: self,
      )
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
