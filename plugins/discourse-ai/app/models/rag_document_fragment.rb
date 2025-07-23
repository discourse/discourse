# frozen_string_literal: true

class RagDocumentFragment < ActiveRecord::Base
  # TODO Jan 2025 - remove
  self.ignored_columns = %i[ai_persona_id]

  belongs_to :upload
  belongs_to :target, polymorphic: true

  class << self
    def link_target_and_uploads(target, upload_ids)
      return if target.blank?
      return if upload_ids.blank?
      return if !DiscourseAi::Embeddings.enabled?

      UploadReference.ensure_exist!(upload_ids: upload_ids, target: target)

      upload_ids.each do |upload_id|
        Jobs.enqueue(
          :digest_rag_upload,
          target_id: target.id,
          target_type: target.class.to_s,
          upload_id: upload_id,
        )
      end
    end

    def update_target_uploads(target, upload_ids)
      return if target.blank?
      return if !DiscourseAi::Embeddings.enabled?

      if upload_ids.blank?
        RagDocumentFragment.where(target: target).destroy_all
        UploadReference.where(target: target).destroy_all
      else
        RagDocumentFragment.where(target: target).where.not(upload_id: upload_ids).destroy_all
        link_target_and_uploads(target, upload_ids)
      end
    end

    def indexing_status(persona, uploads)
      embeddings_table = DiscourseAi::Embeddings::Schema.for(self).table

      results =
        DB.query(
          <<~SQL,
        SELECT
          uploads.id,
          SUM(CASE WHEN (rdf.upload_id IS NOT NULL) THEN 1 ELSE 0 END) AS total,
          SUM(CASE WHEN (eft.rag_document_fragment_id IS NOT NULL) THEN 1 ELSE 0 END) as indexed,
          SUM(CASE WHEN (rdf.upload_id IS NOT NULL AND eft.rag_document_fragment_id IS NULL) THEN 1 ELSE 0 END) as left
        FROM uploads
        LEFT OUTER JOIN rag_document_fragments rdf ON uploads.id = rdf.upload_id AND rdf.target_id = :target_id
          AND rdf.target_type = :target_type
        LEFT OUTER JOIN #{embeddings_table} eft ON rdf.id = eft.rag_document_fragment_id
        WHERE uploads.id IN (:upload_ids)
        GROUP BY uploads.id
      SQL
          target_id: persona.id,
          target_type: persona.class.to_s,
          upload_ids: uploads.map(&:id),
        )

      results.reduce({}) do |acc, r|
        acc[r.id] = { total: r.total, indexed: r.indexed, left: r.left }
        acc
      end
    end

    def publish_status(upload, status)
      MessageBus.publish("/discourse-ai/rag/#{upload.id}", status, user_ids: [upload.user_id])
    end
  end
end

# == Schema Information
#
# Table name: rag_document_fragments
#
#  id              :bigint           not null, primary key
#  fragment        :text             not null
#  upload_id       :integer          not null
#  fragment_number :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  metadata        :text
#  target_id       :bigint           not null
#  target_type     :string(800)      not null
#
# Indexes
#
#  index_rag_document_fragments_on_target_type_and_target_id  (target_type,target_id)
#
