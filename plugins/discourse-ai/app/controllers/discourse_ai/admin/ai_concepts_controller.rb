# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiConceptsController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      DEFAULT_PER_PAGE = 50
      MAX_PER_PAGE = 200
      MAX_FILTER_LENGTH = 200
      TOPICS_LIMIT = 25

      def index
        scope = apply_status_filter(InferredConcept.all)
        scope = apply_text_filter(scope)

        total = scope.count
        page = [params[:page].to_i, 1].max
        per_page = params[:per_page].to_i
        per_page = DEFAULT_PER_PAGE if per_page <= 0
        per_page = per_page.clamp(1, MAX_PER_PAGE)
        offset = (page - 1) * per_page

        concepts = apply_ordering(scope).includes(:parent).offset(offset).limit(per_page).to_a

        raw_counts = InferredConcept.group(:status).count
        counts = {
          active: raw_counts["active"] || 0,
          candidate: raw_counts["candidate"] || 0,
          retired: raw_counts["retired"] || 0,
        }

        render json: {
                 ai_concepts: serialize_concepts(concepts),
                 meta: {
                   total: total,
                   page: page,
                   per_page: per_page,
                   has_more: offset + concepts.size < total,
                   counts: counts,
                   enabled: SiteSetting.inferred_concepts_enabled,
                   embeddings_enabled: DiscourseAi::Embeddings.enabled?,
                 },
               }
      end

      def show
        concept = InferredConcept.includes(:parent, :children).find(params[:id])

        topic_links =
          InferredConceptTopic
            .where(inferred_concept_id: concept.id)
            .joins(:topic)
            .where(topics: { deleted_at: nil, archetype: Archetype.default })
            .order(primary: :desc, relevance: :desc, created_at: :desc)
            .limit(TOPICS_LIMIT)
            .includes(:topic)
            .select { |link| guardian.can_see?(link.topic) }

        render json: {
                 ai_concept: serialize_concept(concept),
                 topics:
                   topic_links.map do |link|
                     {
                       id: link.topic.id,
                       title: link.topic.title,
                       url: link.topic.relative_url,
                       relevance: link.relevance,
                       primary: link.primary,
                       created_at: link.topic.created_at,
                     }
                   end,
                 children:
                   concept
                     .children
                     .order(:name)
                     .map do |child| { id: child.id, name: child.name, status: child.status } end,
               }
      end

      def new
      end

      def edit
      end

      def create
        attrs = normalized_concept_params
        return if performed?

        concept = InferredConcept.new(attrs)

        if concept.save
          if !concept.retired? && DiscourseAi::Embeddings.enabled?
            Jobs.enqueue(
              :generate_embeddings,
              target_type: "InferredConcept",
              target_id: concept.id,
            )
          end

          StaffActionLogger.new(current_user).log_custom(
            "create_ai_concept",
            concept_id: concept.id,
            subject: concept.name,
          )

          render json: { ai_concept: serialize_concept(concept) }, status: :created
        else
          render_json_error(concept)
        end
      end

      def update
        concept = InferredConcept.find(params[:id])
        attrs = normalized_concept_params(existing_parent_id: concept.parent_id)
        return if performed?

        concept.assign_attributes(attrs)
        embedding_changed =
          concept.name_changed? || concept.description_changed? || concept.aliases_changed? ||
            concept.status_changed?

        if concept.save
          if concept.retired?
            DiscourseAi::Embeddings::Schema.delete_embeddings_for(concept)
          elsif embedding_changed && DiscourseAi::Embeddings.enabled?
            Jobs.enqueue(
              :generate_embeddings,
              target_type: "InferredConcept",
              target_id: concept.id,
            )
          end

          StaffActionLogger.new(current_user).log_custom(
            "update_ai_concept",
            concept_id: concept.id,
            subject: concept.name,
          )

          render json: { ai_concept: serialize_concept(concept.reload) }
        else
          render_json_error(concept)
        end
      end

      def destroy
        concept = InferredConcept.find(params[:id])
        concept_id = concept.id
        concept_name = concept.name

        concept.destroy!

        StaffActionLogger.new(current_user).log_custom(
          "delete_ai_concept",
          concept_id: concept_id,
          subject: concept_name,
        )

        head :no_content
      end

      def merge
        source = InferredConcept.find(params[:id])
        target = InferredConcept.find_by(id: params[:target_concept_id])

        if target.nil? || source.id == target.id || source.retired? || target.retired?
          return(
            render_json_error(I18n.t("discourse_ai.concepts.errors.invalid_merge"), status: 422)
          )
        end

        canonical =
          DiscourseAi::InferredConcepts::Merger.new.merge!(canonical: target, duplicates: [source])

        StaffActionLogger.new(current_user).log_custom(
          "merge_ai_concept",
          source_id: source.id,
          target_id: canonical.id,
          subject: "#{source.name} -> #{canonical.name}",
        )

        render json: { ai_concept: serialize_concept(canonical.reload) }
      end

      def curate
        unless SiteSetting.inferred_concepts_enabled && DiscourseAi::Embeddings.enabled?
          return(
            render_json_error(
              I18n.t("discourse_ai.concepts.errors.curation_unavailable"),
              status: 422,
            )
          )
        end

        RateLimiter.new(current_user, "curate-inferred-concepts", 1, 1.minute).performed!
        Jobs.enqueue(:curate_inferred_concepts)
        head :no_content
      end

      private

      def apply_status_filter(scope)
        status = params[:status].to_s
        case status
        when "active", "candidate", "retired"
          scope.where(status: status)
        when "non_retired"
          scope.where.not(status: :retired)
        else
          scope
        end
      end

      def apply_text_filter(scope)
        query = params[:filter].to_s.strip.first(MAX_FILTER_LENGTH)
        return scope if query.blank?

        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        scope.where(
          "inferred_concepts.name ILIKE :pattern OR inferred_concepts.description ILIKE :pattern OR EXISTS (SELECT 1 FROM unnest(inferred_concepts.aliases) AS alias WHERE alias ILIKE :pattern)",
          pattern: pattern,
        )
      end

      def apply_ordering(scope)
        case params[:order].to_s
        when "name"
          scope.order(Arel.sql("lower(inferred_concepts.name) ASC, inferred_concepts.id ASC"))
        when "created_at"
          scope.order(created_at: :desc, id: :desc)
        else
          scope
            .joins(
              "LEFT JOIN (SELECT inferred_concept_id, COUNT(*) AS cnt FROM inferred_concept_topics GROUP BY inferred_concept_id) tc ON tc.inferred_concept_id = inferred_concepts.id",
            )
            .joins(
              "LEFT JOIN (SELECT inferred_concept_id, COUNT(*) AS cnt FROM inferred_concept_posts GROUP BY inferred_concept_id) pc ON pc.inferred_concept_id = inferred_concepts.id",
            )
            .order(
              Arel.sql(
                "(COALESCE(tc.cnt, 0) + COALESCE(pc.cnt, 0)) DESC, lower(inferred_concepts.name) ASC, inferred_concepts.id ASC",
              ),
            )
        end
      end

      def serialize_concepts(concepts)
        ids = concepts.map(&:id)
        topics_counts =
          InferredConceptTopic.where(inferred_concept_id: ids).group(:inferred_concept_id).count
        posts_counts =
          InferredConceptPost.where(inferred_concept_id: ids).group(:inferred_concept_id).count
        children_counts = InferredConcept.where(parent_id: ids).group(:parent_id).count

        ActiveModel::ArraySerializer.new(
          concepts,
          each_serializer: AdminInferredConceptSerializer,
          root: false,
          topics_counts: topics_counts,
          posts_counts: posts_counts,
          children_counts: children_counts,
        ).as_json
      end

      def serialize_concept(concept)
        serialize_concepts([concept]).first
      end

      def normalized_concept_params(existing_parent_id: nil)
        raw =
          params.require(:ai_concept).permit(:name, :description, :status, :parent_id, aliases: [])

        if raw[:status].present? && !InferredConcept.statuses.key?(raw[:status].to_s)
          render_json_error(I18n.t("discourse_ai.concepts.errors.invalid_status"), status: 422)
          return
        end

        if raw.key?(:parent_id)
          if raw[:parent_id].blank? || raw[:parent_id].to_i == 0
            raw[:parent_id] = nil
          else
            parent = InferredConcept.find_by(id: raw[:parent_id])
            if parent.nil? || (parent.retired? && parent.id != existing_parent_id)
              render_json_error(I18n.t("discourse_ai.concepts.errors.invalid_parent"), status: 422)
              return
            end
            raw[:parent_id] = parent.id
          end
        end

        raw
      end
    end
  end
end
