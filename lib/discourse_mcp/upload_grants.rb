# frozen_string_literal: true

module DiscourseMcp
  # Uploads granted to the OAuth authorization that created them through MCP.
  #
  # While a content rule is active, an agent may only reference or assign
  # uploads its own authorization created. A grant stays usable only while
  # every record that references the upload is one this authorization wrote:
  # once a human uses the same upload elsewhere, its content may come from or
  # be shown next to restricted content, so the agent can no longer use it.
  module UploadGrants
    module_function

    # Grants an upload to the caller's authorization.
    #
    # @param upload [Upload]
    # @param request_context [RequestContext]
    # @returns [void]
    def grant!(upload, request_context)
      McpUploadGrant.insert_all(
        [{ upload_id: upload.id, mcp_oauth_authorization_id: request_context.authorization_id }],
        unique_by: %i[mcp_oauth_authorization_id upload_id],
      )
    end

    # @param upload [Upload]
    # @param request_context [RequestContext]
    # @returns [Boolean] Whether the caller may use the upload.
    def usable?(upload, request_context)
      grant =
        McpUploadGrant.find_by(
          upload_id: upload.id,
          mcp_oauth_authorization_id: request_context.authorization_id,
        )
      return false if grant.blank?

      !UploadReference
        .where(upload_id: upload.id)
        .where.not(
          "EXISTS (SELECT 1 FROM mcp_upload_grant_targets t
                   WHERE t.mcp_upload_grant_id = :grant_id
                     AND t.target_type = upload_references.target_type
                     AND t.target_id = upload_references.target_id)",
          grant_id: grant.id,
        )
        .exists?
    end

    POST_TOOLS = %w[
      discourse_create_topic
      discourse_create_post
      discourse_update_post
      discourse_create_private_message
      discourse_reply_private_message
    ].freeze

    # The records a write tool stored the agent's text or uploads on, read
    # from its result, as `[target_type, target_id]` pairs of upload
    # references. A write whose result names no record, such as a queued
    # post, records nothing, so its uploads can't be used again.
    #
    # @param tool_identifier [String]
    # @param result [Hash] The tool's result.
    # @param request_context [RequestContext]
    # @returns [Set<Array(String, Integer)>]
    def written_targets(tool_identifier, result, request_context)
      data = (result.is_a?(Hash) && result[:structuredContent]).to_h.with_indifferent_access
      records =
        if POST_TOOLS.include?(tool_identifier)
          [Post.find_by(id: data[:id])]
        else
          case tool_identifier
          when "discourse_update_user"
            user_records(User.find_by(id: request_context.user_id))
          when "discourse_create_user"
            user_records(User.find_by(id: data[:user_id]))
          when "discourse_create_group", "discourse_update_group"
            [Group.find_by(id: data[:id] || data.dig(:group, :id))]
          when "discourse_create_category", "discourse_update_category"
            category = Category.find_by(id: data[:id] || data.dig(:category, :id))
            [category, category&.topic&.first_post]
          when "discourse_save_draft"
            [Draft.find_by(user_id: request_context.user_id, draft_key: data[:draft_key])]
          else
            []
          end
        end
      records.compact.map { |record| [record.class.polymorphic_name, record.id] }.to_set
    end

    def user_records(user)
      user ? [user, user.user_profile, user.user_avatar] : []
    end

    # Records the references to granted uploads that a call created as records
    # the authorization wrote. A reference only counts when it was created
    # after the call began and its target is a record the call wrote, so a
    # human's use, earlier or during the call, is never adopted.
    #
    # @param upload_ids [Enumerable<Integer>]
    # @param request_context [RequestContext]
    # @param since [Time] When the call began.
    # @param targets [Set<Array(String, Integer)>] From `written_targets`.
    # @returns [void]
    def record_written!(upload_ids, request_context, since:, targets:)
      return if upload_ids.empty? || targets.empty?

      grants =
        McpUploadGrant
          .where(
            upload_id: upload_ids.to_a,
            mcp_oauth_authorization_id: request_context.authorization_id,
          )
          .pluck(:upload_id, :id)
          .to_h
      return if grants.empty?

      rows =
        UploadReference
          .where(upload_id: grants.keys)
          .where("created_at >= ?", since)
          .pluck(:upload_id, :target_type, :target_id)
          .select { |_, target_type, target_id| targets.include?([target_type, target_id]) }
          .map do |upload_id, target_type, target_id|
            { mcp_upload_grant_id: grants[upload_id], target_type:, target_id: }
          end
      return if rows.empty?

      McpUploadGrantTarget.insert_all(
        rows,
        unique_by: :index_mcp_upload_grant_targets_on_grant_and_target,
      )
    end
  end
end
