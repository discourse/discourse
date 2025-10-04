# frozen_string_literal: true

module ::DiscourseSharedEdits
  class RevisionController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    requires_login
    before_action :ensure_logged_in, :ensure_shared_edits
    skip_before_action :preload_json, :check_xhr

    def enable
      guardian.ensure_can_toggle_shared_edits!
      SharedEditRevision.toggle_shared_edits!(params[:post_id].to_i, true)
      render json: success_json
    end

    def disable
      guardian.ensure_can_toggle_shared_edits!
      SharedEditRevision.toggle_shared_edits!(params[:post_id].to_i, false)
      render json: success_json
    end

    def latest
      post = Post.find(params[:post_id].to_i)
      guardian.ensure_can_see!(post)
      Rails.logger.info "[SharedEdits] Latest request for post #{post.id}"

      begin
        SharedEditRevision.commit!(post.id, apply_to_post: false)
      rescue => e
        Rails.logger.error "[SharedEdits] Commit failed in latest: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        # Continue anyway, we'll return what we have
      end

      version, raw, yjs_state = SharedEditRevision.latest_raw(post)
      Rails.logger.info "[SharedEdits] Latest response - version: #{version}, raw_length: #{raw&.length}, has_yjs_state: #{!yjs_state.nil?}, yjs_state_type: #{yjs_state.class}"

      # Parse yjs_state if it's a string (may be double-encoded)
      parsed_yjs_state = nil
      if yjs_state
        begin
          if yjs_state.is_a?(String)
            first_parse = JSON.parse(yjs_state)
            Rails.logger.info "[SharedEdits] First parse type: #{first_parse.class}"

            # Check if it's double-encoded (parsed to string, needs second parse)
            if first_parse.is_a?(String)
              Rails.logger.info "[SharedEdits] Data is double-encoded, parsing again"
              parsed_yjs_state = JSON.parse(first_parse)
            else
              parsed_yjs_state = first_parse
            end
          else
            parsed_yjs_state = yjs_state
          end
          Rails.logger.info "[SharedEdits] Final parsed yjs_state type: #{parsed_yjs_state.class}, is_array: #{parsed_yjs_state.is_a?(Array)}, is_hash: #{parsed_yjs_state.is_a?(Hash)}"
        rescue JSON::ParserError => e
          Rails.logger.error "[SharedEdits] Failed to parse yjs_state: #{e.message}"
          parsed_yjs_state = nil
        end
      end

      render json: { raw: raw, version: version, yjsState: parsed_yjs_state }
    end

    def commit
      params.require(:post_id)

      post = Post.find(params[:post_id].to_i)
      guardian.ensure_can_see!(post)
      Rails.logger.info "[SharedEdits] Commit request for post #{post.id}"

      # If yjsState is provided (from client), save it as the final revision
      if params[:yjsState].present?
        begin
          Rails.logger.info "[SharedEdits] Saving final YJS state, length: #{params[:yjsState].length}"

          # Create a final revision with the YJS state
          SharedEditRevision.revise!(
            post_id: post.id,
            user_id: current_user.id,
            client_id: params[:client_id] || "final",
            version: params[:version].to_i,
            revision: params[:yjsState],
          )
        rescue => e
          Rails.logger.error "[SharedEdits] Failed to save final state: #{e.message}"
          # Continue with commit anyway
        end
      end

      # Clear the auto-commit lock so any pending commits are cancelled
      Discourse.redis.del(SharedEditRevision.will_commit_key(post.id))

      # Commit all changes to the post
      SharedEditRevision.commit!(post.id)
      Rails.logger.info "[SharedEdits] Commit successful for post #{post.id}"

      render json: success_json
    end

    def revise
      params.require(:client_id)
      params.require(:version)

      master_version = params[:version].to_i

      post = Post.find(params[:post_id].to_i)
      guardian.ensure_can_see!(post)

      has_yjs_update = params[:yjsUpdate].present?
      has_awareness = params[:awareness].present?

      Rails.logger.info "[SharedEdits] Revise request for post #{post.id} - client: #{params[:client_id]}, version: #{master_version}, update_length: #{params[:yjsUpdate]&.length}, awareness_length: #{params[:awareness]&.length}"

      version = master_version
      revision = nil
      revisions = []

      # Only create a revision if we have a YJS update
      if has_yjs_update
        # Extract raw text if provided by client
        raw_text = params[:raw] if params[:raw].present?

        version, revision =
          SharedEditRevision.revise!(
            post_id: post.id,
            user_id: current_user.id,
            client_id: params[:client_id],
            version: master_version,
            revision: params[:yjsUpdate],
            raw: raw_text,
          )

        Rails.logger.info "[SharedEdits] Revise completed - new version: #{version}, has_raw: #{!!raw_text}"

        revisions =
          if version == master_version + 1
            [
              {
                version: version,
                revision: revision,
                client_id: params[:client_id],
                type: "yjs-update",
              },
            ]
          else
            SharedEditRevision
              .where(post_id: post.id)
              .where("version > ?", master_version)
              .order(:version)
              .pluck(:revision, :version, :client_id)
              .map { |r, v, c| { version: v, revision: r, client_id: c, type: "yjs-update" } }
          end
      end

      # Publish to message bus
      message = { client_id: params[:client_id], user_id: current_user.id }

      # Add YJS update if present
      if has_yjs_update
        message[:version] = version
        message[:revision] = revision
        message[:type] = "yjs-update"
        message[:update] = revision
      end

      # Add awareness if present
      if has_awareness
        message[:awareness] = params[:awareness]
        Rails.logger.info "[SharedEdits] Including awareness in message bus broadcast"
      end

      Rails.logger.info "[SharedEdits] Publishing to message bus - channel: /shared_edits/#{post.id}, client: #{params[:client_id]}"
      post.publish_message!("/shared_edits/#{post.id}", message)

      # Only ensure auto-commit if we had a YJS update
      SharedEditRevision.ensure_will_commit(post.id) if has_yjs_update

      Rails.logger.info "[SharedEdits] Revise response - version: #{version}, revisions_count: #{revisions.length}"
      render json: { version: version, revisions: revisions }
    end

    protected

    def ensure_shared_edits
      raise Discourse::InvalidAccess if !SiteSetting.shared_edits_enabled
    end
  end
end
