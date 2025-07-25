# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ArtifactKeyValuesController < ::ApplicationController
      requires_plugin DiscourseAi::PLUGIN_NAME
      before_action :ensure_logged_in, only: %i[set destroy]
      before_action :find_artifact

      PER_PAGE_MAX = 100

      def index
        page = index_params[:page].to_i
        page = 1 if page < 1
        per_page = index_params[:per_page].to_i
        per_page = PER_PAGE_MAX if per_page < 1 || per_page > PER_PAGE_MAX

        query = build_index_query

        total_count = query.count
        key_values =
          query
            .includes(:user)
            .order(:user_id, :key, :created_at)
            .offset((page - 1) * per_page)
            .limit(per_page + 1)

        has_more = key_values.length > per_page
        key_values = key_values.first(per_page) if has_more

        render json: {
                 key_values:
                   ActiveModel::ArraySerializer.new(
                     key_values,
                     each_serializer: AiArtifactKeyValueSerializer,
                     keys_only: params[:keys_only] == "true",
                   ).as_json,
                 has_more: has_more,
                 total_count: total_count,
                 users:
                   key_values
                     .map { |kv| kv.user }
                     .uniq
                     .map { |u| BasicUserSerializer.new(u, root: nil).as_json },
               }
      end

      def destroy
        if params[:key].blank?
          render json: { error: "Key parameter is required" }, status: :bad_request
          return
        end

        key_value = @artifact.key_values.find_by(user_id: current_user.id, key: params[:key])

        if key_value.nil?
          render json: { error: "Key not found" }, status: :not_found
        elsif key_value.destroy
          head :ok
        else
          render json: { errors: key_value.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def set
        key_value =
          @artifact.key_values.find_or_initialize_by(
            user: current_user,
            key: key_value_params[:key],
          )

        key_value.assign_attributes(key_value_params.except(:key))

        if key_value.save
          render json: AiArtifactKeyValueSerializer.new(key_value).as_json
        else
          render json: { errors: key_value.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def key_value_params
        params.permit(:key, :value, :public)
      end

      def index_params
        @index_params ||= params.permit(:page, :per_page, :key, :keys_only, :all_users)
      end

      def build_index_query
        query = @artifact.key_values

        query =
          if current_user&.admin?
            query
          elsif current_user
            query.where("user_id = ? OR public = true", current_user.id)
          else
            query.where(public: true)
          end

        query = query.where("key = ?", index_params[:key]) if index_params[:key].present?

        if index_params[:all_users].to_s != "true"
          if current_user
            query = query.where(user_id: current_user.id)
          else
            query = query.where("1 = 0")
          end
        end

        query
      end

      def find_artifact
        @artifact = AiArtifact.find_by(id: params[:artifact_id])
        raise Discourse::NotFound if !@artifact
        raise Discourse::NotFound if !@artifact.public? && guardian.anonymous?
        raise Discourse::NotFound if !@artifact.public? && !guardian.can_see?(@artifact.post)
      end
    end
  end
end
