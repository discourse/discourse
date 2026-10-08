# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ArtifactSharesController < ::ApplicationController
      requires_plugin PLUGIN_NAME
      requires_login
      before_action :require_artifacts!, only: %i[eligibility create update]
      before_action :require_management!, only: %i[index destroy]

      def eligibility
        artifact = AiArtifact.find_by(id: params[:id])
        can_share = eligible?(artifact)
        share = AiArtifactShare.find_by(ai_artifact: artifact, user: current_user) if can_share
        render json: {
                 can_share: can_share,
                 share:
                   share &&
                     { share_key: share.share_key, url: share.url, version: share.version_number },
               }
      end

      def index
        render json:
                 ArtifactSharesQuery.new(
                   user: current_user,
                   type: params[:type],
                   order: params[:order],
                   cursor: params[:cursor],
                 ).call
      end

      def create
        artifact = AiArtifact.find_by(id: params[:id])
        raise Discourse::NotFound if !eligible?(artifact)

        RateLimiter.new(current_user, "share-ai-artifact", 10, 1.minute).performed!
        version = requested_version(artifact)
        share = AiArtifactShare.find_by(ai_artifact: artifact, user: current_user)
        return render_share(share, version: version) if share

        snapshot =
          AiArtifactShare.new(ai_artifact: artifact, user: current_user).snapshot_attributes(
            version_number: version,
          )
        inserted =
          AiArtifactShare.insert_all(
            [
              snapshot.merge(
                ai_artifact_id: artifact.id,
                user_id: current_user.id,
                share_key: SecureRandom.urlsafe_base64(32),
              ),
            ],
            unique_by: :index_ai_artifact_shares_on_user_id_and_ai_artifact_id,
          )
        share = AiArtifactShare.find_by!(ai_artifact: artifact, user: current_user)
        return render_share(share, version: version) if inserted.rows.empty?

        render json: {
                 share_key: share.share_key,
                 url: share.url,
                 version: share.version_number,
               },
               status: :created
      rescue ActiveRecord::RecordNotUnique
        render_share(
          AiArtifactShare.find_by!(ai_artifact: artifact, user: current_user),
          version: version,
        )
      end

      def update
        share = owned_share
        raise Discourse::NotFound if !eligible?(share.ai_artifact)

        RateLimiter.new(current_user, "share-ai-artifact", 10, 1.minute).performed!
        version = requested_version(share.ai_artifact)
        share.pin!(version_number: version)
        render json: { share_key: share.share_key, url: share.url, version: share.version_number }
      end

      def destroy
        owned_share.destroy!
        head :no_content
      end

      private

      def owned_share
        AiArtifactShare.where(user: current_user).find_by!(share_key: params[:share_key])
      end

      def render_share(share, version:)
        if share.version_number != version
          message = I18n.t("discourse_ai.ai_artifact.share_version_conflict")
          return render json: { error: message, errors: [message] }, status: :conflict
        end

        render json: { share_key: share.share_key, url: share.url, version: share.version_number }
      end

      def eligible?(artifact)
        return false if !artifact

        post = artifact.post
        topic = post&.topic
        if !post || post.deleted_at || !topic || topic.deleted_at || !guardian.can_see?(post)
          return false
        end
        return false if !guardian.can_share_ai_bot_conversation?(topic)

        artifact.user_id == current_user.id ||
          (
            topic.user_id == current_user.id &&
              DiscourseAi::AiBot::EntryPoint.all_bot_ids.include?(artifact.user_id)
          )
      end

      def requested_version(artifact)
        raise Discourse::NotFound if !params[:version].to_s.match?(/\A(?:0|[1-9]\d*)\z/)

        version = params[:version].to_i
        if version != 0 && !artifact.versions.exists?(version_number: version)
          raise Discourse::NotFound
        end

        version
      end

      def require_management!
        raise Discourse::NotFound if !SiteSetting.discourse_ai_enabled
      end

      def require_artifacts!
        if !SiteSetting.discourse_ai_enabled ||
             !SiteSetting.ai_artifact_security.in?(%w[lax hybrid strict])
          raise Discourse::NotFound
        end
      end
    end
  end
end
