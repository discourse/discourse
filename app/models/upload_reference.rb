# frozen_string_literal: true

class UploadReference < ActiveRecord::Base
  belongs_to :upload
  belongs_to :target, polymorphic: true

  delegate :to_markdown, to: :upload

  def self.ensure_exist!(upload_ids: [], target: nil, target_type: nil, target_id: nil)
    if !target && !(target_type && target_id)
      raise "target OR target_type and target_id are required"
    end

    if target.present?
      target_type = target.class
      target_id = target.id
    end

    upload_ids = upload_ids.uniq.reject(&:blank?)
    target_type = target_type.to_s

    if upload_ids.empty?
      UploadReference.where(target_type: target_type, target_id: target_id).delete_all

      return
    end

    rows =
      upload_ids.map do |upload_id|
        {
          upload_id: upload_id,
          target_type: target_type,
          target_id: target_id,
          created_at: Time.zone.now,
          updated_at: Time.zone.now,
        }
      end

    UploadReference.transaction do |transaction|
      UploadReference
        .where(target_type: target_type, target_id: target_id)
        .where.not(upload_id: upload_ids)
        .delete_all

      UploadReference.insert_all(rows)
    end
  end
end

# == Schema Information
#
# Table name: upload_references
#
#  id          :bigint           not null, primary key
#  upload_id   :bigint           not null
#  target_type :string           not null
#  target_id   :bigint           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_upload_references_on_target             (target_type,target_id)
#  index_upload_references_on_upload_and_target  (upload_id,target_type,target_id) UNIQUE
#  index_upload_references_on_upload_id          (upload_id)
#
