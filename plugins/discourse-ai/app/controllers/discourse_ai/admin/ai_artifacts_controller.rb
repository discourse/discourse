# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiArtifactsController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      PER_PAGE_MAX = 100

      before_action :find_artifact, only: %i[show update destroy]

      def index
        page = params[:page].to_i
        page = 1 if page < 1
        per_page = params[:per_page].to_i
        per_page = 50 if per_page < 1
        per_page = PER_PAGE_MAX if per_page > PER_PAGE_MAX

        base = AiArtifact.all
        total = base.count

        artifacts = base.order(created_at: :desc).offset((page - 1) * per_page).limit(per_page)

        render json: {
                 artifacts: serialize_data(artifacts, AiArtifactSerializer),
                 meta: {
                   total: total,
                   page: page,
                   per_page: per_page,
                   has_more: total > page * per_page,
                 },
               }
      end

      def show
        render_serialized(@artifact, AiArtifactSerializer)
      end

      def create
        artifact = AiArtifact.new(artifact_params)

        if artifact.save
          render_serialized(artifact, AiArtifactSerializer, status: :created)
        else
          render_json_error artifact
        end
      end

      def update
        if @artifact.update(artifact_params)
          render_serialized(@artifact, AiArtifactSerializer)
        else
          render_json_error @artifact
        end
      end

      def destroy
        if @artifact.destroy
          head :no_content
        else
          render_json_error @artifact
        end
      end

      private

      def find_artifact
        @artifact = AiArtifact.find(params[:id])
      end

      def artifact_params
        params.require(:ai_artifact).permit(
          :user_id,
          :post_id,
          :name,
          :html,
          :css,
          :js,
          metadata: {
          },
        )
      end
    end
  end
end
