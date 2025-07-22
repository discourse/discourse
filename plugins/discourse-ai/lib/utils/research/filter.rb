# frozen_string_literal: true

module DiscourseAi
  module Utils
    module Research
      class Filter
        def self.register_filter(matcher, &block)
          (@registered_filters ||= {})[matcher] = block
        end

        def self.registered_filters
          @registered_filters ||= {}
        end

        def self.word_to_date(str)
          ::Search.word_to_date(str)
        end

        attr_reader :term, :filters, :order, :guardian, :limit, :offset, :invalid_filters

        register_filter(/\Astatus:open\z/i) do |relation, _, _|
          relation.where("topics.closed = false AND topics.archived = false")
        end

        register_filter(/\Astatus:closed\z/i) do |relation, _, _|
          relation.where("topics.closed = true")
        end

        register_filter(/\Astatus:archived\z/i) do |relation, _, _|
          relation.where("topics.archived = true")
        end

        register_filter(/\Astatus:noreplies\z/i) do |relation, _, _|
          relation.where("topics.posts_count = 1")
        end

        register_filter(/\Astatus:single_user\z/i) do |relation, _, _|
          relation.where("topics.participant_count = 1")
        end

        # Date filters
        register_filter(/\Abefore:(.*)\z/i) do |relation, date_str, _|
          if date = Filter.word_to_date(date_str)
            relation.where("posts.created_at < ?", date)
          else
            relation
          end
        end

        register_filter(/\Aafter:(.*)\z/i) do |relation, date_str, _|
          if date = Filter.word_to_date(date_str)
            relation.where("posts.created_at > ?", date)
          else
            relation
          end
        end

        register_filter(/\Atopic_before:(.*)\z/i) do |relation, date_str, _|
          if date = Filter.word_to_date(date_str)
            relation.where("topics.created_at < ?", date)
          else
            relation
          end
        end

        register_filter(/\Atopic_after:(.*)\z/i) do |relation, date_str, _|
          if date = Filter.word_to_date(date_str)
            relation.where("topics.created_at > ?", date)
          else
            relation
          end
        end

        register_filter(/\A(?:tags?|tag):(.*)\z/i) do |relation, tag_param, _|
          if tag_param.include?(",")
            tag_names = tag_param.split(",").map(&:strip)
            tag_ids = Tag.where(name: tag_names).pluck(:id)
            return relation.where("1 = 0") if tag_ids.empty?
            relation.where(topic_id: TopicTag.where(tag_id: tag_ids).select(:topic_id))
          else
            if tag = Tag.find_by(name: tag_param)
              relation.where(topic_id: TopicTag.where(tag_id: tag.id).select(:topic_id))
            else
              relation.where("1 = 0")
            end
          end
        end

        register_filter(/\Akeywords?:(.*)\z/i) do |relation, keywords_param, _|
          if keywords_param.blank?
            relation
          else
            keywords = keywords_param.split(",").map(&:strip).reject(&:blank?)
            if keywords.empty?
              relation
            else
              # Build a ts_query string joined by | (OR)
              ts_query = keywords.map { |kw| kw.gsub(/['\\]/, " ") }.join(" | ")
              relation =
                relation.joins("JOIN post_search_data ON post_search_data.post_id = posts.id")
              relation.where(
                "post_search_data.search_data @@ to_tsquery(?, ?)",
                ::Search.ts_config,
                ts_query,
              )
            end
          end
        end

        register_filter(/\Atopic_keywords?:(.*)\z/i) do |relation, keywords_param, _|
          if keywords_param.blank?
            relation
          else
            keywords = keywords_param.split(",").map(&:strip).reject(&:blank?)
            if keywords.empty?
              relation
            else
              ts_query = keywords.map { |kw| kw.gsub(/['\\]/, " ") }.join(" | ")

              relation.where(
                "posts.topic_id IN (
                  SELECT posts2.topic_id
                  FROM posts posts2
                  JOIN post_search_data ON post_search_data.post_id = posts2.id
                  WHERE post_search_data.search_data @@ to_tsquery(?, ?)
                )",
                ::Search.ts_config,
                ts_query,
              )
            end
          end
        end

        register_filter(/\A(?:categories?|category):(.*)\z/i) do |relation, category_param, _|
          if category_param.include?(",")
            category_names = category_param.split(",").map(&:strip)

            found_category_ids = []
            category_names.each do |name|
              category = Category.find_by(slug: name) || Category.find_by(name: name)
              found_category_ids << category.id if category
            end

            return relation.where("1 = 0") if found_category_ids.empty?
            relation.where(topic_id: Topic.where(category_id: found_category_ids).select(:id))
          else
            if category =
                 Category.find_by(slug: category_param) || Category.find_by(name: category_param)
              relation.where(topic_id: Topic.where(category_id: category.id).select(:id))
            else
              relation.where("1 = 0")
            end
          end
        end

        register_filter(/\Ausernames?:(.+)\z/i) do |relation, username, filter|
          user_ids = User.where(username_lower: username.split(",").map(&:downcase)).pluck(:id)
          if user_ids.empty?
            relation.where("1 = 0")
          else
            relation.where("posts.user_id IN (?)", user_ids)
          end
        end

        def self.assign_allowed?(guardian)
          SiteSetting.respond_to?(:assign_enabled) && SiteSetting.assign_enabled &&
            (guardian.can_assign? || SiteSetting.assigns_public)
        end

        register_filter(/\Aassigned_to:(.+)\z/i) do |relation, name, filter|
          if !assign_allowed?(filter.guardian)
            raise Discourse::InvalidAccess.new(
                    "Assigns are not enabled or you do not have permission to see assigns.",
                  )
          end

          if (name == "nobody")
            relation.joins("LEFT JOIN assignments a ON a.topic_id = topics.id AND a.active").where(
              "a.assigned_to_id IS NULL",
            )
          elsif name == "*"
            relation.joins("JOIN assignments a ON a.topic_id = topics.id AND a.active").where(
              "a.assigned_to_id IS NOT NULL",
            )
          else
            usernames = name.split(",").map(&:strip).map(&:downcase)
            relation.joins("JOIN assignments a ON a.topic_id = topics.id AND a.active").where(
              "a.assigned_to_id" => User.where(username_lower: usernames).select(:id),
            )
          end
        end

        register_filter(/\Agroups?:([a-zA-Z0-9_\-,]+)\z/i) do |relation, groups_param, filter|
          if groups_param.include?(",")
            group_names = groups_param.split(",").map(&:strip)
            found_group_ids = []
            group_names.each do |name|
              group = Group.find_by("name ILIKE ?", name)
              found_group_ids << group.id if group
            end

            return relation.where("1 = 0") if found_group_ids.empty?
            relation.where(
              "posts.user_id IN (
                SELECT gu.user_id FROM group_users gu
                WHERE gu.group_id IN (?)
              )",
              found_group_ids,
            )
          else
            group = Group.find_by("name ILIKE ?", groups_param)
            if group
              relation.where(
                "posts.user_id IN (
                SELECT gu.user_id FROM group_users gu
                WHERE gu.group_id = ?
              )",
                group.id,
              )
            else
              relation.where("1 = 0") # No results if group doesn't exist
            end
          end
        end

        register_filter(/\Amax_results:(\d+)\z/i) do |relation, limit_str, filter|
          filter.limit_by_user!(limit_str.to_i)
          relation
        end

        register_filter(/\Aorder:latest\z/i) do |relation, order_str, filter|
          filter.set_order!(:latest_post)
          relation
        end

        register_filter(/\Aorder:oldest\z/i) do |relation, order_str, filter|
          filter.set_order!(:oldest_post)
          relation
        end

        register_filter(/\Aorder:latest_topic\z/i) do |relation, order_str, filter|
          filter.set_order!(:latest_topic)
          relation
        end

        register_filter(/\Aorder:oldest_topic\z/i) do |relation, order_str, filter|
          filter.set_order!(:oldest_topic)
          relation
        end

        register_filter(/\Aorder:likes\z/i) do |relation, order_str, filter|
          filter.set_order!(:likes)
          relation
        end

        register_filter(/\Atopics?:(.*)\z/i) do |relation, topic_param, filter|
          if topic_param.include?(",")
            topic_ids = topic_param.split(",").map(&:strip).map(&:to_i).reject(&:zero?)
            return relation.where("1 = 0") if topic_ids.empty?
            relation.where("posts.topic_id IN (?)", topic_ids)
          else
            topic_id = topic_param.to_i
            if topic_id > 0
              relation.where("posts.topic_id = ?", topic_id)
            else
              relation.where("1 = 0") # No results if topic_id is invalid
            end
          end
        end

        register_filter(/\Apost_type:(first|reply)\z/i) do |relation, post_type, _|
          if post_type.downcase == "first"
            relation.where("posts.post_number = 1")
          elsif post_type.downcase == "reply"
            relation.where("posts.post_number > 1")
          else
            relation
          end
        end

        def initialize(term, guardian: nil, limit: nil, offset: nil)
          @guardian = guardian || Guardian.new
          @limit = limit
          @offset = offset
          @filters = []
          @valid = true
          @order = :latest_post
          @invalid_filters = []
          @term = term.to_s.strip
          @or_groups = []

          process_filters(@term)
        end

        def set_order!(order)
          @order = order
        end

        def limit_by_user!(limit)
          @limit = limit if limit.to_i < @limit.to_i || @limit.nil?
        end

        def search
          base_relation =
            Post
              .secured(@guardian)
              .joins(:topic)
              .merge(Topic.secured(@guardian))
              .where("topics.archetype = 'regular'")

          # Handle OR groups
          if @or_groups.any?
            or_relations =
              @or_groups.map do |or_group|
                group_relation = base_relation
                or_group.each do |filter_block, match_data|
                  group_relation = filter_block.call(group_relation, match_data, self)
                end
                group_relation
              end

            # Combine OR groups
            filtered = or_relations.reduce { |combined, current| combined.or(current) }
          else
            filtered = base_relation
          end

          # Apply regular AND filters
          @filters.each do |filter_block, match_data|
            filtered = filter_block.call(filtered, match_data, self)
          end

          filtered = filtered.limit(@limit) if @limit.to_i > 0
          filtered = filtered.offset(@offset) if @offset.to_i > 0

          if @order == :latest_post
            filtered = filtered.order("posts.created_at DESC")
          elsif @order == :oldest_post
            filtered = filtered.order("posts.created_at ASC")
          elsif @order == :latest_topic
            filtered = filtered.order("topics.created_at DESC, posts.post_number DESC")
          elsif @order == :oldest_topic
            filtered = filtered.order("topics.created_at ASC, posts.post_number ASC")
          elsif @order == :likes
            filtered = filtered.order("posts.like_count DESC, posts.created_at DESC")
          end

          filtered
        end

        def process_filters(term)
          return if term.blank?

          # Split by OR first, then process each group
          or_parts = term.split(/\s+OR\s+/i)

          if or_parts.size > 1
            # Multiple OR groups
            or_parts.each do |or_part|
              group_filters = []
              process_filter_group(or_part.strip, group_filters)
              @or_groups << group_filters if group_filters.any?
            end
          else
            # Single group (AND logic)
            process_filter_group(term, @filters)
          end
        end

        private

        def process_filter_group(term_part, filter_collection)
          term_part
            .to_s
            .scan(/(([^" \t\n\x0B\f\r]+)?(("[^"]+")?))/)
            .to_a
            .map do |(word, _)|
              next if word.blank?

              found = false
              self.class.registered_filters.each do |matcher, block|
                if word =~ matcher
                  filter_collection << [block, $1]
                  found = true
                  break
                end
              end

              invalid_filters << word if !found
            end
        end
      end
    end
  end
end
