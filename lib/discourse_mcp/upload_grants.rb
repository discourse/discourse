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

    # Records the references to granted uploads that a call created as records
    # the authorization wrote. A reference only counts when it was created
    # after the call began, so a human's earlier use is never adopted.
    #
    # @param upload_ids [Enumerable<Integer>]
    # @param request_context [RequestContext]
    # @param since [Time] When the call began.
    # @returns [void]
    def record_written!(upload_ids, request_context, since:)
      return if upload_ids.empty?

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
