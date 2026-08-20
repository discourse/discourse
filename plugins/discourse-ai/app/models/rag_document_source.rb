# frozen_string_literal: true

class RagDocumentSource < ActiveRecord::Base
  MIN_REFRESH_INTERVAL_HOURS = 1
  MAX_REFRESH_INTERVAL_HOURS = 8_760

  belongs_to :target, polymorphic: true
  belongs_to :upload, optional: true

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

  def due?
    next_refresh_at.nil? || next_refresh_at <= Time.zone.now
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
    return if upload_id.blank?

    RagDocumentFragment.where(target:, upload_id: upload_id).destroy_all
    UploadReference.where(target:, upload_id: upload_id).destroy_all
  end
end
