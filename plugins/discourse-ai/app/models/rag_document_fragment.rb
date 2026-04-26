# frozen_string_literal: true

class RagDocumentFragment < ActiveRecord::Base
  MAX_SEARCH_RESULTS = 200
  MAX_GET_FILE_CHARS = 500_000

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

    def indexing_status(agent, uploads)
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
          target_id: agent.id,
          target_type: agent.class.to_s,
          upload_ids: uploads.map(&:id),
        )

      results.reduce({}) do |acc, r|
        acc[r.id] = { total: r.total, indexed: r.indexed, left: r.left }
        acc
      end
    end

    def search(target_id:, target_type:, query:, filenames: nil, limit: 10)
      return [] if !DiscourseAi::Embeddings.enabled?
      return [] if query.blank?

      limit = limit.to_i
      return [] if limit < 1

      limit = [MAX_SEARCH_RESULTS, limit].min
      upload_ids = upload_ids_for(target_id:, target_type:, filenames:)
      return [] if upload_ids.empty?

      query_vector = DiscourseAi::Embeddings::Vector.instance.vector_from(query)
      fragment_ids =
        DiscourseAi::Embeddings::Schema
          .for(self)
          .asymmetric_similarity_search(query_vector, limit: limit, offset: 0) do |builder|
            builder.join(<<~SQL, target_id: target_id, target_type: target_type)
              rag_document_fragments ON
                rag_document_fragments.id = rag_document_fragment_id AND
                rag_document_fragments.target_id = :target_id AND
                rag_document_fragments.target_type = :target_type
            SQL
          end
          .map(&:rag_document_fragment_id)

      uploads_by_id = Upload.where(id: upload_ids).pluck(:id, :original_filename).to_h
      fragments =
        where(
          id: fragment_ids,
          upload_id: upload_ids,
          target_id: target_id,
          target_type: target_type,
        ).pluck(:id, :fragment, :metadata, :upload_id, :fragment_number)

      fragments_by_id = {}
      fragments.each do |id, fragment, metadata, upload_id, fragment_number|
        fragments_by_id[id] = {
          fragment: fragment,
          metadata: metadata,
          filename: uploads_by_id[upload_id],
          fragment_number: fragment_number,
        }
      end

      fragment_ids.filter_map { |fragment_id| fragments_by_id[fragment_id] }.take(limit)
    end

    def read_file(target_id:, target_type:, filename:)
      return nil if filename.blank?

      upload_ids = upload_ids_for(target_id:, target_type:, filenames: [filename])
      return nil if upload_ids.empty?

      upload_id =
        Upload.where(id: upload_ids, original_filename: filename).order(id: :desc).pick(:id)
      return nil if upload_id.nil?

      fragments =
        where(target_id:, target_type:, upload_id: upload_id).order(:fragment_number).pluck(
          :fragment,
        )

      return nil if fragments.empty?

      result = +""
      fragments.each do |fragment|
        if result.length + fragment.length + 1 > MAX_GET_FILE_CHARS
          result << "\n[truncated]"
          break
        end
        result << "\n" unless result.empty?
        result << fragment
      end
      result
    end

    def publish_status(upload, status)
      MessageBus.publish("/discourse-ai/rag/#{upload.id}", status, user_ids: [upload.user_id])
    end

    private

    def upload_ids_for(target_id:, target_type:, filenames: nil)
      upload_ids =
        UploadReference.where(target_id: target_id, target_type: target_type).pluck(:upload_id)
      return upload_ids if filenames.blank?

      normalized_filenames = Array(filenames).filter_map(&:presence)
      return [] if normalized_filenames.empty?

      Upload.where(id: upload_ids, original_filename: normalized_filenames).pluck(:id)
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
