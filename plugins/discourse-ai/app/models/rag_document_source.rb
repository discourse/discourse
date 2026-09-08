# frozen_string_literal: true

class RagDocumentSource < ActiveRecord::Base
  MIN_REFRESH_INTERVAL_HOURS = 1
  MAX_REFRESH_INTERVAL_HOURS = 8_760

  belongs_to :target, polymorphic: true
  belongs_to :upload, optional: true
  belongs_to :pending_upload, class_name: "Upload", optional: true

  validates :target_type, inclusion: { in: %w[AiAgent] }
  validates :url, presence: true, length: { maximum: 2000 }
  validates :url_digest, presence: true, length: { is: 64 }
  validates :url_digest, uniqueness: { scope: %i[target_type target_id] }
  validates :refresh_interval_hours,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: MIN_REFRESH_INTERVAL_HOURS,
              less_than_or_equal_to: MAX_REFRESH_INTERVAL_HOURS,
            }
  validate :validate_url

  before_validation :normalize_url
  before_validation :set_url_digest
  before_save :expire_changed_source
  before_destroy :remove_rag_content
  after_commit :enqueue_refresh, on: %i[create update]

  scope :due, -> { where(next_refresh_at: nil).or(where("next_refresh_at <= ?", Time.zone.now)) }

  class << self
    def promote_pending_upload(target:, upload:)
      find_by(target:, pending_upload_id: upload.id)&.promote_pending_upload!(upload)
    end

    def mark_indexing_failed(target:, upload:, error:)
      find_by(target:, pending_upload_id: upload.id)&.mark_indexing_failed!(error)
    end
  end

  def due?
    next_refresh_at.nil? || next_refresh_at <= Time.zone.now
  end

  def indexing_status
    return "failed" if last_error.present?
    return "indexing" if pending_upload_id.present?
    return "indexed" if upload_id.present?

    "pending"
  end

  def promote_pending_upload!(upload)
    with_lock do
      return if pending_upload_id != upload.id

      old_upload_id = upload_id
      UploadReference.ensure_exist!(upload_ids: [upload.id], target:)
      update_columns(
        upload_id: upload.id,
        pending_upload_id: nil,
        last_error_at: nil,
        last_error: nil,
        updated_at: Time.zone.now,
      )
      remove_rag_content_for(old_upload_id) if old_upload_id.present? && old_upload_id != upload.id
    end
  end

  def mark_indexing_failed!(error)
    update_columns(
      next_refresh_at: 1.hour.from_now,
      last_error_at: Time.zone.now,
      last_error: error.message.to_s.truncate(4000),
      updated_at: Time.zone.now,
    )
  end

  private

  def normalize_url
    uri = URI.parse(url.to_s.strip)
    uri.fragment = nil
    self.url = uri.normalize.to_s
  rescue URI::InvalidURIError
    self.url = url.to_s.strip
  end

  def set_url_digest
    self.url_digest = Digest::SHA256.hexdigest(url.to_s)
  end

  def expire_changed_source
    if url_changed?
      self.etag = nil
      self.last_modified = nil
      self.next_refresh_at = nil
    elsif refresh_interval_hours_changed?
      self.next_refresh_at = nil
    end
  end

  def validate_url
    uri = URI.parse(url.to_s)
    valid = uri.scheme.in?(%w[http https]) && uri.host.present? && uri.userinfo.blank?
    errors.add(:url, :invalid) if !valid
  rescue URI::InvalidURIError
    errors.add(:url, :invalid)
  end

  def enqueue_refresh
    if !previous_changes.key?("id") && !previous_changes.key?("url") &&
         !previous_changes.key?("refresh_interval_hours")
      return
    end

    Jobs.enqueue(:refresh_rag_document_source, rag_document_source_id: id)
  end

  def remove_rag_content
    [upload_id, pending_upload_id].compact.uniq.each { |id| remove_rag_content_for(id) }
  end

  def remove_rag_content_for(id)
    RagDocumentFragment.where(target:, upload_id: id).destroy_all
    UploadReference.where(target:, upload_id: id).destroy_all
  end
end

# == Schema Information
#
# Table name: rag_document_sources
#
#  id                     :bigint           not null, primary key
#  etag                   :string
#  last_error             :text
#  last_error_at          :datetime
#  last_fetched_at        :datetime
#  last_modified          :string
#  managed                :boolean          default(FALSE), not null
#  next_refresh_at        :datetime
#  refresh_interval_hours :integer          default(24), not null
#  target_type            :string(800)      not null
#  url                    :string(2000)     not null
#  url_digest             :string(64)       not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  pending_upload_id      :integer
#  target_id              :bigint           not null
#  upload_id              :integer
#
# Indexes
#
#  idx_rag_document_sources_target_url                      (target_type,target_id,url_digest) UNIQUE
#  index_rag_document_sources_on_next_refresh_at            (next_refresh_at)
#  index_rag_document_sources_on_target_type_and_target_id  (target_type,target_id)
#
