# frozen_string_literal: true

module DiscourseMcp
  module Tools
    module SiteSettingSupport
      CREDENTIAL_NAME =
        /(?:\A|_)(?:secret|token|password|passphrase|private_key|access_keys?|api_keys?|credentials?)(?:\z|_)/i
      UNSUPPORTED_TYPES = %w[upload uploaded_image_list uploaded-image-list objects].freeze
      UPDATE_POLICIES = %i[
        settings_are_not_deprecated
        settings_are_unshadowed_globally
        settings_are_visible
        settings_are_configurable
      ].freeze

      module_function

      def ensure_admin!(guardian)
        guardian.ensure_is_admin!
      end

      def settings(arguments = {}, include_hidden: false)
        SiteSetting.all_settings(
          include_hidden:,
          filter_categories: arguments["categories"],
          filter_plugin: arguments["plugin"],
          filter_names: arguments["names"],
        )
      end

      def exact_setting(name)
        settings({ "names" => [name] }).reverse.find { |setting| setting[:setting].to_s == name }
      end

      def blocked?(setting)
        setting[:secret] || setting[:setting].to_s.match?(CREDENTIAL_NAME)
      end

      def unsupported_type?(setting)
        setting[:themeable] == true || UNSUPPORTED_TYPES.include?(setting[:type].to_s)
      end

      # While any rule is active, a setting's value and default are redacted
      # when they name a restricted category, tag or topic, or link to one. A
      # personal message is such a topic while agent access to them is off.
      def redact(projected, policy)
        return projected if !policy.active?

        values = %i[value default].map { |key| projected[key] }
        restricted = values.any? { |value| restricted_value?(projected, value, policy) }
        return projected if !restricted

        projected.merge(value: nil, default: nil, redacted: true)
      end

      def restricted_value?(projected, value, policy)
        return false if value.blank?

        items = value.to_s.split("|")
        case projected[:type]
        when "category"
          items.any? { |id| !policy.allows_category_id?(id.to_i) }
        when "category_list"
          items.any? { |id| !policy.allows_category_id?(id.to_i) }
        when "tag_list"
          items.any? { |name| !policy.allows_tag?(name) }
        else
          if projected[:setting].end_with?("_topic_id")
            value.to_i.positive? && Topic.exists?(id: value.to_i) &&
              !policy.allows_topic_id?(value.to_i)
          else
            items.any? { |item| restricted_local_url?(item, policy) }
          end
        end
      end

      MAX_REDIRECTS = 5
      JUDGED_PARAMS = %i[topic_id post_id category_id tag_id category_slug_path_with_id].freeze
      RECORD_ID_CONTROLLERS = %w[topics posts categories tags].freeze
      # Controllers whose identifiers name records no content rule governs.
      UNGOVERNED_CONTROLLERS = %w[users groups badges].freeze

      # A local URL is restricted when anything it leads to on the site is: the
      # records its route names through any parameter that identifies one, the
      # destination of a redirect route, or the target of a permalink. They are
      # resolved in the order the router serves them, so a live route wins over
      # a permalink with the same path. A local URL that the server doesn't
      # serve is restricted too, because the browser or a later redirect may
      # still route it to restricted content. A URL to a record that doesn't
      # exist is kept: settings are written by admins, and agents can't change
      # them while a rule is active.
      def restricted_local_url?(item, policy, hops: 0)
        item = item.to_s.strip
        path, query = local_path(item)
        return restricted_route?(Discourse.route_for(item), policy) if path.nil?
        return true if hops > MAX_REDIRECTS

        full_path = query.present? ? "#{path}?#{query}" : path
        route = recognize(path)
        return restricted_route?(route, policy) if route && route[:controller] != "permalinks"

        destination = redirect_destination(full_path)
        return restricted_local_url?(destination, policy, hops: hops + 1) if destination

        # Permalinks match the full path, query included.
        permalink = Permalink.find_by_url(full_path)
        return true if permalink.nil?

        target = permalink.target_url
        target.present? && restricted_local_url?(target, policy, hops: hops + 1)
      end

      # The path of a URL on this site, without the base path, and its query,
      # or nil when the value isn't written as a URL to this site.
      def local_path(item)
        return if !item.start_with?("/") && !item.match?(%r{\Ahttps?://}i)

        uri = URI.parse(item.start_with?("//") ? "http:#{item}" : item)
        return if uri.host.present? && !local_host?(uri.host)

        path = uri.path.to_s
        path = path.delete_prefix(Discourse.base_path) if path.start_with?(Discourse.base_path)
        [path.presence || "/", uri.query]
      rescue URI::Error
        nil
      end

      def local_host?(host)
        hosts = [Discourse.current_hostname, URI.parse(Discourse.base_url).host]
        hosts.compact.map(&:downcase).include?(host.downcase)
      end

      def recognize(path)
        Rails.application.routes.recognize_path(path)
      rescue ActionController::RoutingError
        nil
      end

      # Redirect routes aren't recognized as controller routes, so the first
      # redirect route that matches resolves to its destination.
      def redirect_destination(path)
        request =
          ActionDispatch::Request.new(
            Rack::MockRequest.env_for(path, "HTTP_HOST" => Discourse.current_hostname),
          )
        Rails
          .application
          .routes
          .router
          .recognize(request) do |route, params|
            next if route.app.engine? || !route.app.matches?(request)

            endpoint = route.app.respond_to?(:app) ? route.app.app : route.app
            return nil if !endpoint.respond_to?(:redirect?) || !endpoint.redirect?

            destination = endpoint.path(params, request).to_s
            return destination.match?(%r{\A(?:/|https?://)}i) ? destination : "/#{destination}"
          end
        nil
      end

      def restricted_route?(route, policy)
        return false if route.blank?

        restricted_route_topic?(route, policy) || restricted_route_category?(route, policy) ||
          restricted_route_tag?(route, policy) || restricted_route_record?(route, policy)
      end

      # Any other parameter that identifies a record is judged through the
      # model its controller or name points to, by the topic, post or category
      # that record belongs to. An identifier that can't be judged that way is
      # treated as restricted.
      def restricted_route_record?(route, policy)
        controller = route[:controller].to_s
        return false if UNGOVERNED_CONTROLLERS.include?(controller)

        route.any? do |key, value|
          key = key.to_s
          next false if value.blank? || JUDGED_PARAMS.include?(key.to_sym)
          next false if !key.match?(/(?:\A|_)id\z/)
          next false if key == "id" && RECORD_ID_CONTROLLERS.include?(controller)
          next false if key == "external_id" && controller == "topics"

          restricted_record?(route_model(controller, key), value, policy)
        end
      end

      def route_model(controller, key)
        names =
          if key == "id"
            [controller.classify]
          else
            name = key.delete_suffix("_id").classify
            namespace = controller.include?("/") ? controller.split("/")[0...-1].join("/") : nil
            [("#{namespace.classify}::#{name}" if namespace), name].compact
          end
        names
          .lazy
          .map(&:safe_constantize)
          .find { |model| model.is_a?(Class) && model < ActiveRecord::Base }
      end

      def restricted_record?(model, value, policy)
        return true if model.nil?

        record = model.find_by(model.primary_key => value.to_s)
        return false if record.nil?

        links =
          %i[topic_id post_id category_id topic post category].select do |name|
            record.respond_to?(name)
          end
        return true if links.empty?

        topic_ids = [record.try(:topic_id), record.try(:topic)&.id]
        post_ids = [record.try(:post_id), record.try(:post)&.id].compact
        topic_ids.concat(Post.with_deleted.where(id: post_ids).pluck(:topic_id)) if post_ids.any?
        category_ids = [record.try(:category_id), record.try(:category)&.id].compact

        topic_ids.compact.uniq.any? do |topic_id|
          Topic.with_deleted.exists?(id: topic_id) && !policy.allows_topic_id?(topic_id)
        end || category_ids.any? { |category_id| !policy.allows_category_id?(category_id) }
      end

      def restricted_route_topic?(route, policy)
        topic_ids = []
        topic_ids << route[:topic_id].to_i if numeric?(route[:topic_id])

        post_ids = [route[:post_id]]
        post_ids << route[:id] if route[:controller] == "posts"
        post_ids = post_ids.select { |id| numeric?(id) }.map(&:to_i)
        topic_ids.concat(Post.with_deleted.where(id: post_ids).pluck(:topic_id)) if post_ids.any?

        if route[:controller] == "topics" && route[:id].present?
          id = route[:id].to_s
          topic_ids << id.to_i if numeric?(id)
          topic_ids.concat(Topic.with_deleted.where(slug: id).pluck(:id))
        end
        if route[:controller] == "topics" && route[:external_id].present?
          topic_ids.concat(
            Topic.with_deleted.where(external_id: route[:external_id].to_s).pluck(:id),
          )
        end

        Topic
          .with_deleted
          .where(id: topic_ids.uniq)
          .pluck(:id)
          .any? { |topic_id| !policy.allows_topic_id?(topic_id) }
      end

      def restricted_route_category?(route, policy)
        categories = []
        [
          route[:category_slug_path_with_id],
          (route[:path] if route[:controller] == "categories"),
        ].compact_blank.each { |path| categories << Category.find_by_slug_path_with_id(path.to_s) }
        if numeric?(route[:category_id])
          categories << Category.find_by(id: route[:category_id].to_i)
        end

        slugs = [route[:category_slug]]
        if route[:controller] == "categories" && route[:id].present?
          categories << Category.find_by(id: route[:id].to_i) if numeric?(route[:id])
          slugs << route[:id]
        end
        slugs = slugs.compact_blank.map(&:to_s)
        categories.concat(Category.where(slug: slugs).to_a) if slugs.any?

        categories.compact.any? { |category| !policy.allows_category_id?(category.id) }
      end

      # A numeric tag id falls back to a tag with that name, so both readings
      # are checked.
      def restricted_route_tag?(route, policy)
        ids = [route[:tag_id]]
        ids << route[:id] if route[:controller] == "tags"
        ids = ids.compact_blank.map(&:to_s)
        names = [
          *ids,
          route[:tag_name],
          route[:tag_slug],
          *route[:additional_tag_names].to_s.split("/"),
        ]
        names = names.compact_blank.map { |name| name.to_s.downcase }

        tags = Tag.where(id: ids.select { |id| numeric?(id) }.map(&:to_i)).to_a
        tags.concat(Tag.where("LOWER(name) IN (?) OR slug IN (?)", names, names).to_a) if names.any?
        tags.any? { |tag| !policy.allows_tag?(tag) }
      end

      def numeric?(value)
        value.to_s.match?(/\A\d+\z/)
      end

      def project(setting)
        blocked = blocked?(setting)
        {
          setting: setting[:setting].to_s,
          humanized_name: setting[:humanized_name].to_s.first(500),
          description: setting[:description].to_s.first(4_000),
          category: setting[:category],
          primary_area: setting[:primary_area],
          plugin: setting[:plugin],
          type: setting[:type].to_s,
          value: blocked ? nil : setting[:value],
          default: blocked ? nil : setting[:default],
          secret: blocked,
          overridden: setting[:value].to_s != setting[:default].to_s,
          valid_values: bounded_collection(setting[:valid_values]),
          min: setting[:min],
          max: setting[:max],
          mandatory_values: bounded_collection(setting[:mandatory_values]),
          requires_confirmation: setting[:requires_confirmation].present?,
          depends_on: Array(setting[:depends_on]).first(50).map(&:to_s),
          depends_behavior: setting[:depends_behavior]&.to_s,
          depends_on_values: bounded_hash(setting[:depends_on_values]),
          themeable: setting[:themeable] == true,
          editable_by_this_tool: !blocked && !unsupported_type?(setting),
        }
      end

      def bounded_collection(value)
        return [] if !value.is_a?(Array)

        value
          .first(200)
          .map do |item|
            if item.is_a?(Hash)
              item
                .slice(:id, :name, :value, "id", "name", "value")
                .transform_values { |entry| entry.to_s.first(1_000) }
            else
              item.to_s.first(1_000)
            end
          end
      end

      def bounded_hash(value)
        return {} if !value.is_a?(Hash)

        value
          .first(50)
          .to_h do |key, item|
            [key.to_s.first(200), Array(item).first(50).map { |entry| entry.to_s.first(1_000) }]
          end
      end

      def normalize(value)
        case value
        when Array
          value.map(&:to_s).join("|")
        when TrueClass
          "true"
        when FalseClass
          "false"
        else
          value.to_s
        end
      end

      def serialize(value)
        value.is_a?(Array) ? value.map(&:to_s).join("|") : value
      end

      def ensure_dependencies!(setting)
        dependencies = Array(setting[:depends_on]).map(&:to_s)
        return {} if dependencies.empty?

        definitions =
          settings({ "names" => dependencies }, include_hidden: true).index_by do |item|
            item[:setting].to_s
          end
        allowed_values = setting[:depends_on_values].is_a?(Hash) ? setting[:depends_on_values] : {}
        unsatisfied =
          dependencies.reject do |name|
            definition = definitions[name]
            next false if definition.blank?

            allowed = allowed_values[name] || allowed_values[name.to_sym]
            if allowed
              Array(allowed).map(&:to_s).include?(definition[:value].to_s)
            else
              %w[true 1 yes].include?(definition[:value].to_s.downcase)
            end
          end
        if unsatisfied.present?
          raise ToolError,
                I18n.t("mcp.errors.site_setting_dependency", settings: unsatisfied.join(", "))
        end

        dependencies.to_h { |name| [name, definitions.fetch(name)[:value]] }
      end

      def update!(guardian, setting_name, value, expected_values:)
        result =
          SiteSetting::Update.call(
            guardian:,
            params: {
              settings: [{ setting_name:, value: serialize(value) }],
            },
            options: {
              expected_values:,
            },
          )
        return if result.success?

        if result["result.try.default"]&.exception.is_a?(SiteSetting::Update::Conflict)
          raise ToolError, I18n.t("mcp.errors.site_setting_conflict")
        end

        raise ToolError, update_error(result)
      rescue Discourse::InvalidParameters => error
        raise ToolError, error.message
      end

      def update_error(result)
        contract = result["result.contract.default"]
        return contract.errors.full_messages.to_sentence if contract&.failure?

        UPDATE_POLICIES.each do |policy_name|
          policy = result["result.policy.#{policy_name}"]
          return policy.reason if policy&.failure? && policy.reason.present?
        end
        result["result.step.save"]&.exception&.message.presence ||
          I18n.t("mcp.errors.site_setting_update_failed")
      end
    end

    class ListSiteSettings
      REQUIRED_SCOPES = [Scopes::SITE_SETTINGS_READ].freeze
      CONTENT = {
        topics: :enforced,
        private_messages: :enforced,
        categories: :enforced,
        tags: :enforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(site_settings: OutputSchema::OBJECT_ARRAY, meta: OutputSchema::OBJECT)

      def self.call(arguments:, request_context:)
        SiteSettingSupport.ensure_admin!(request_context.guardian)
        offset = arguments.fetch("offset", 0)
        limit = arguments.fetch("limit", 100)
        requested_names = Array(arguments["names"]).to_set
        rows =
          SiteSettingSupport
            .settings(arguments)
            .select do |setting|
              requested_names.empty? || requested_names.include?(setting[:setting].to_s)
            end
        if arguments["overridden_only"]
          rows.select! { |setting| setting[:value].to_s != setting[:default].to_s }
        end
        page = rows.slice(offset, limit) || []
        has_more = offset + page.length < rows.length
        ToolHelpers.text_and_structured(
          site_settings:
            page.map do |setting|
              SiteSettingSupport.redact(
                SiteSettingSupport.project(setting),
                request_context.content_policy,
              )
            end,
          meta: {
            offset:,
            limit:,
            returned: page.length,
            total: rows.length,
            overridden_only: arguments.fetch("overridden_only", false),
            has_more:,
            next_offset: has_more ? offset + page.length : nil,
          },
        )
      end
    end

    class UpdateSiteSetting
      REQUIRED_SCOPES = [Scopes::SITE_SETTINGS_WRITE].freeze
      CONTENT = {
        topics: :unenforced,
        private_messages: :unenforced,
        categories: :unenforced,
        tags: :unenforced,
        exit_paths: :unenforced,
      }.freeze
      OUTPUT_SCHEMA =
        OutputSchema.object(
          updated: OutputSchema::BOOLEAN,
          setting: OutputSchema::STRING,
          operation: OutputSchema::STRING,
          before: OutputSchema::OBJECT,
          after: OutputSchema::OBJECT,
          verified: OutputSchema::BOOLEAN,
        )

      def self.call(arguments:, request_context:)
        guardian = request_context.guardian
        SiteSettingSupport.ensure_admin!(guardian)
        if arguments["confirm_change"] != true
          raise ToolError, I18n.t("mcp.errors.site_setting_change_confirmation_required")
        end
        setting_name = arguments.fetch("setting")
        setting = SiteSettingSupport.exact_setting(setting_name)
        raise ToolError, I18n.t("mcp.errors.site_setting_not_found") if setting.blank?
        if SiteSettingSupport.blocked?(setting)
          raise ToolError, I18n.t("mcp.errors.site_setting_sensitive")
        end
        if SiteSettingSupport.unsupported_type?(setting)
          raise ToolError, I18n.t("mcp.errors.site_setting_type_unsupported")
        end

        expected_values = SiteSettingSupport.ensure_dependencies!(setting)
        expected = SiteSettingSupport.normalize(arguments.fetch("expected_current_value"))
        if expected != SiteSettingSupport.normalize(setting[:value])
          raise ToolError, I18n.t("mcp.errors.site_setting_conflict")
        end
        if setting[:requires_confirmation].present? && !arguments["confirm_required_setting"]
          raise ToolError, I18n.t("mcp.errors.site_setting_confirmation_required")
        end

        operation = arguments.fetch("operation")
        value =
          case operation
          when "set"
            if !arguments.key?("value")
              raise ToolError, I18n.t("mcp.errors.site_setting_value_required")
            end
            arguments["value"]
          when "reset_to_default"
            if arguments.key?("value")
              raise ToolError, I18n.t("mcp.errors.site_setting_value_forbidden")
            end
            setting[:default]
          end
        if SiteSettingSupport.normalize(value) == SiteSettingSupport.normalize(setting[:value])
          raise ToolError, I18n.t("mcp.errors.site_setting_no_change")
        end

        before = SiteSettingSupport.project(setting)
        SiteSettingSupport.update!(
          guardian,
          setting_name,
          value,
          expected_values: expected_values.merge(setting_name => setting[:value]),
        )
        after_setting = SiteSettingSupport.exact_setting(setting_name)
        if after_setting.blank?
          raise ToolError, I18n.t("mcp.errors.site_setting_verification_failed")
        end
        if SiteSettingSupport.normalize(after_setting[:value]) ==
             SiteSettingSupport.normalize(setting[:value])
          raise ToolError, I18n.t("mcp.errors.site_setting_no_change")
        end

        ToolHelpers.text_and_structured(
          updated: true,
          setting: setting_name,
          operation:,
          before:,
          after: SiteSettingSupport.project(after_setting),
          verified: true,
        )
      end
    end
  end
end
