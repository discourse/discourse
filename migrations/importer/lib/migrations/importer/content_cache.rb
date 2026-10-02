# frozen_string_literal: true

module Migrations
  module Importer
    class ContentCache
      Store = Migrations::ContentCache::Store
      PORTABLE_TAGS = %w[
        p
        br
        hr
        strong
        em
        s
        del
        ul
        ol
        li
        blockquote
        pre
        code
        a
        h1
        h2
        h3
        h4
        h5
        h6
      ].freeze
      PORTABLE_ATTRIBUTES = %w[href title rel target start].freeze

      attr_reader :counts

      def initialize
        @counts = Hash.new(0)
      end

      def export(path)
        @export_urls = ContentCacheUrls.new(url_bases, url_bases)
        Store.write(
          path,
          { "urls" => url_bases, "renderer" => renderer, "exported_at" => Time.now.utc.iso8601 },
        ) do |store|
          each_mapped(Post) do |post, original_id|
            translations =
              post.localizations.filter_map do |localization|
                if localization.post_version != post.version
                  @counts[:stale_translations] += 1
                  next
                end
                translation_payload(localization)
              end
            store.put(
              "post",
              original_id,
              Store.digest(post.raw),
              {
                "locale" => post.locale,
                "cooked" => post.cooked,
                "baked_version" => post.baked_version,
                "rewrite_fields" => (@export_urls.marked?(post.cooked) ? ["cooked"] : []),
                "context" => cooking_context(post),
                "uploads" => upload_dependencies(post),
                "translations" => translations,
              },
            )
            @counts[:exported_posts] += 1
          end
          each_mapped(Topic) do |topic, original_id|
            store.put(
              "topic",
              original_id,
              topic_hash(topic),
              {
                "locale" => topic.locale,
                "translations" =>
                  topic.localizations.filter_map do |localization|
                    translation_payload(localization)
                  end,
              },
            )
            @counts[:exported_topics] += 1
          end
        end
        @counts
      end

      def restore(path)
        if SiteSetting.respond_to?(:ai_translation_enabled) && SiteSetting.ai_translation_enabled
          raise ArgumentError,
                "Disable ai_translation_enabled and pause translation jobs before restoring the content cache"
        end
        store = Store.new(path)
        @urls = ContentCacheUrls.new(store.metadata.fetch("urls"), url_bases)
        @renderer_matches = store.metadata.fetch("renderer") == renderer
        each_mapped(Post) do |post, original_id|
          source_hash = Store.digest(post.raw)
          payload = store.get("post", original_id, source_hash)
          next @counts[:post_misses] += 1 unless payload && compatible_locale?(post, payload)

          Post.transaction do
            post.lock!
            next unless Store.digest(post.raw) == source_hash && compatible_locale?(post, payload)
            restore_locale(post, payload)
            restore_cooked(post, payload)
            payload
              .fetch("translations")
              .each do |translation|
                restore_post_translation(post, translation, payload["context"])
              end
          end
        end
        each_mapped(Topic) do |topic, original_id|
          source_hash = topic_hash(topic)
          payload = store.get("topic", original_id, source_hash)
          next @counts[:topic_misses] += 1 unless payload && compatible_locale?(topic, payload)

          Topic.transaction do
            topic.lock!
            next unless topic_hash(topic) == source_hash && compatible_locale?(topic, payload)
            restore_locale(topic, payload)
            payload
              .fetch("translations")
              .each { |translation| restore_topic_translation(topic, translation) }
          end
        end
        @counts
      ensure
        store&.close
      end

      def capture_existing_sources
        @post_sources = {}
        Post
          .where(id: PostLocalization.select(:post_id))
          .select(:id, :raw)
          .find_each { |post| @post_sources[post.id] = Store.digest(post.raw) }
        @topic_sources = {}
        Topic
          .where(id: TopicLocalization.select(:topic_id))
          .includes(:first_post)
          .find_each { |topic| @topic_sources[topic.id] = topic_hash(topic) }
      end

      def invalidate_changed_sources
        Post
          .where(id: @post_sources&.keys)
          .find_each do |post|
            next if @post_sources[post.id] == Store.digest(post.raw)
            post.localizations.destroy_all
            post.update_column(:locale, nil)
            @counts[:invalidated_posts] += 1
          end
        Topic
          .where(id: @topic_sources&.keys)
          .includes(:first_post)
          .find_each do |topic|
            next if @topic_sources[topic.id] == topic_hash(topic)
            topic.localizations.destroy_all
            topic.update_column(:locale, nil)
            @counts[:invalidated_topics] += 1
          end
      end

      private

      def each_mapped(model)
        name = model.model_name.singular
        field_model = "#{model.name}CustomField".constantize
        valid_values =
          field_model.where(name: "import_id").group(:value).having("COUNT(*) = 1").select(:value)
        valid_ids =
          field_model
            .where(name: "import_id")
            .group("#{name}_id")
            .having("COUNT(*) = 1")
            .select("#{name}_id")
        fields =
          field_model
            .where(name: "import_id", value: valid_values)
            .where.not(value: [nil, ""])
            .where("#{name}_id" => valid_ids)
        @counts[:"ambiguous_#{name}_mappings"] += field_model.where(name: "import_id").count -
          fields.count
        fields.in_batches do |batch|
          mappings = batch.pluck("#{name}_id", :value).to_h
          scope = model.where(id: mappings.keys).includes(:localizations)
          scope =
            (
              if model == Post
                scope.includes(:topic, :user, :uploads, localizations: :uploads)
              else
                scope.includes(:first_post)
              end
            )
          scope.each { |record| yield record, mappings.fetch(record.id) }
        end
      end

      def url_bases
        {
          "site" => Discourse.base_url,
          "cdn" => Discourse.asset_host.presence,
          "uploads" => Discourse.store.absolute_base_url,
          "upload_cdn" => SiteSetting.Upload.s3_cdn_url.presence,
          "relative_uploads" =>
            (Discourse.store.relative_base_url unless Discourse.store.external?),
        }.tap do |bases|
          bases.to_a.each do |role, base|
            bases["#{role}_schemeless"] = base.sub(/\Ahttps?:/, "") if base&.match?(%r{\Ahttps?://})
          end
        end
      end

      def renderer
        settings =
          SiteSetting
            .all_settings(include_hidden: true)
            .filter_map do |setting|
              name = setting[:setting].to_s
              next if name.start_with?("ai_", "content_localization_", "discourse_ai_")
              next if %w[s3_cdn_url s3_upload_bucket].include?(name)
              [name, setting[:value]]
            end
            .sort_by(&:first)
        Store.digest(
          Discourse.git_version,
          Post::BAKED_VERSION,
          settings,
          Discourse.plugins.map { |plugin| [plugin.name, plugin.metadata.version] }.sort,
        )
      end

      def cooking_context(post)
        [post.cooking_options, post.omit_nofollow?]
      end

      def topic_hash(topic)
        Store.digest(topic.title, topic.excerpt, topic.first_post&.raw)
      end

      def compatible_locale?(record, payload)
        record.locale.blank? || record.locale == payload["locale"]
      end

      def restore_locale(record, payload)
        if record.locale.blank? && payload["locale"].present?
          record.update_column(:locale, payload["locale"])
        end
      end

      def translation_payload(localization)
        user_id = localization.localizer_user_id
        attribution =
          if user_id == Discourse::SYSTEM_USER_ID
            { "system" => true }
          else
            values = UserCustomField.where(user_id:, name: "import_id").pluck(:value)
            values.one? ? { "original_id" => values.first } : nil
          end
        unless attribution
          @counts[:unmapped_localizers] += 1
          return
        end
        attributes =
          localization.attributes.slice(
            "locale",
            "raw",
            "cooked",
            "title",
            "excerpt",
            "created_at",
            "updated_at",
          )
        attributes.merge(
          "rewrite_fields" =>
            %w[raw cooked excerpt].select { |field| @export_urls.marked?(attributes[field]) },
          "localizer" => attribution,
          "uploads" => (upload_dependencies(localization) if localization.is_a?(PostLocalization)),
        )
      end

      def localizer_id(translation)
        return Discourse::SYSTEM_USER_ID if translation.fetch("localizer")["system"]
        ids =
          UserCustomField.where(
            name: "import_id",
            value: translation.fetch("localizer").fetch("original_id"),
          ).pluck(:user_id)
        ids.first if ids.one? && User.exists?(ids.first)
      end

      def rewrite_field(payload, field, format)
        text = payload[field]
        return text unless text && payload.fetch("rewrite_fields").include?(field)
        rewritten = @urls.public_send(format, text)
        @counts[:rewritten_fields] += 1 if rewritten != text
        rewritten
      end

      def upload_dependencies(record)
        record.uploads.to_h { |upload| [upload.sha1, upload.url] }
      end

      def uploads_match?(dependencies)
        return true if dependencies.empty?
        destination = Upload.where(sha1: dependencies.keys).pluck(:sha1, :url).to_h
        dependencies.all? { |sha1, url| destination[sha1] == @urls.url(url) }
      end

      def portable_html?(html)
        return false if html.blank?
        Nokogiri::HTML5
          .fragment(html)
          .css("*")
          .all? do |node|
            PORTABLE_TAGS.include?(node.name) &&
              node.attribute_nodes.all? { |attribute| PORTABLE_ATTRIBUTES.include?(attribute.name) }
          end
      end

      def restore_cooked(post, payload)
        if @renderer_matches && payload["baked_version"] == Post::BAKED_VERSION &&
             payload["context"] == JSON.parse(JSON.generate(cooking_context(post))) &&
             portable_html?(payload["cooked"]) && uploads_match?(payload.fetch("uploads"))
          cooked = rewrite_field(payload, "cooked", :html)
          post.update_columns(cooked:, baked_version: Post::BAKED_VERSION, baked_at: Time.zone.now)
          post.link_post_uploads
          TopicLink.extract_from(post)
          QuotedPost.extract_from(post)
          post.sync_first_post_caches
          @counts[:cooked_hits] += 1
        else
          @counts[:cooked_misses] += 1
          # Topic translation matching needs the final source excerpt, even when
          # the remaining uncooked posts will be rebaked by the import runbook.
          if post.is_first_post? && post.baked_version != Post::BAKED_VERSION
            Jobs::ProcessPost.new.execute(
              post_id: post.id,
              cook: true,
              bypass_bump: true,
              skip_pull_hotlinked_images: true,
            )
            post.reload.sync_first_post_caches
            TopicLink.extract_from(post)
            QuotedPost.extract_from(post)
          end
        end
      rescue ContentCacheUrls::Unresolved
        @counts[:unresolved_urls] += 1
      end

      def restore_post_translation(post, translation, context)
        existing = PostLocalization.find_by(post_id: post.id, locale: translation.fetch("locale"))
        return @counts[:existing_translations] += 1 if existing &&
          existing.post_version == post.version
        user_id = localizer_id(translation)
        return @counts[:unmapped_localizers] += 1 unless user_id
        raw = rewrite_field(translation, "raw", :raw)
        missing_upload =
          raw
            .scan(%r{upload://[^\s\)\]"<>]+})
            .any? do |url|
              sha1 = Upload.sha1_from_short_url(url)
              !sha1 || !Upload.exists?(sha1:)
            end
        return @counts[:missing_uploads] += 1 if missing_upload

        cooked =
          if @renderer_matches && context == JSON.parse(JSON.generate(cooking_context(post))) &&
               portable_html?(translation.fetch("cooked")) &&
               uploads_match?(translation.fetch("uploads"))
            rewrite_field(translation, "cooked", :html)
          else
            post.post_analyzer.cook(raw, post.cooking_options || {})
          end
        existing&.destroy!
        localization =
          PostLocalization.create!(
            post_id: post.id,
            locale: translation.fetch("locale"),
            raw:,
            cooked:,
            post_version: post.version,
            localizer_user_id: user_id,
            created_at: translation["created_at"],
            updated_at: translation["updated_at"],
          )
        processor = LocalizedCookedPostProcessor.new(localization, post, {})
        processor.post_process
        localization.update_column(:cooked, processor.html)
        @counts[:restored_post_translations] += 1
      rescue ContentCacheUrls::Unresolved
        @counts[:unresolved_urls] += 1
      end

      def restore_topic_translation(topic, translation)
        return @counts[:existing_translations] += 1 if TopicLocalization.exists?(
          topic_id: topic.id,
          locale: translation.fetch("locale"),
        )
        user_id = localizer_id(translation)
        return @counts[:unmapped_localizers] += 1 unless user_id
        title = translation.fetch("title")
        localization =
          TopicLocalization.create!(
            topic_id: topic.id,
            locale: translation.fetch("locale"),
            title:,
            fancy_title: Topic.fancy_title(title),
            excerpt: rewrite_field(translation, "excerpt", :html),
            localizer_user_id: user_id,
            created_at: translation["created_at"],
            updated_at: translation["updated_at"],
          )
        first_translation = topic.first_post&.localizations&.find_by(locale: localization.locale)
        localization.update_excerpt(cooked: first_translation.cooked) if first_translation
        @counts[:restored_topic_translations] += 1
      rescue ContentCacheUrls::Unresolved
        @counts[:unresolved_urls] += 1
      end
    end
  end
end
