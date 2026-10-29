# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ComposerPaused
      class V1 < NodeType
        PAUSE = "pause"
        DRAFT_SAVED = "draft_saved"
        FIRE_ON_OPTIONS = [PAUSE, DRAFT_SAVED].freeze
        MAX_PHRASES = 50
        MAX_PHRASE_LENGTH = 100
        # A phrase that matches any of these would match nearly every draft.
        MATCH_ANYTHING_SAMPLES = ["", " ", "zq"].freeze

        COMPOSER_PROPERTIES = {
          "action" => {
            "type" => "string",
            "enum" => ComposerSnapshot::ACTIONS,
          },
          "draft_key" => {
            "type" => "string",
          },
          "session_id" => {
            "type" => %w[string null],
          },
          "title" => {
            "type" => %w[string null],
          },
          "raw" => {
            "type" => "string",
          },
          "category_id" => {
            "type" => %w[integer null],
          },
          "topic_id" => {
            "type" => %w[integer null],
          },
          "reply_to_post_number" => {
            "type" => %w[integer null],
          },
          "matched_phrases" => {
            "type" => "array",
            "items" => {
              "type" => "string",
            },
          },
        }.freeze

        description(
          name: "trigger:composer_paused",
          version: "1.0",
          defaults: {
            icon: "keyboard",
            color: "cyan",
          },
          group: "discourse_triggers",
          properties: {
            fire_on: {
              type: :options,
              required: true,
              default: PAUSE,
              options: FIRE_ON_OPTIONS,
            },
            phrases: {
              type: :array,
              required: false,
              no_data_expression: true,
              ui: {
                control: :multi_input,
              },
            },
            composer_actions: {
              type: :multi_options,
              required: false,
              default: ComposerSnapshot::ACTIONS,
              options: ComposerSnapshot::ACTIONS,
            },
            **CATEGORY_FILTER_PROPERTIES,
            group_ids: {
              type: :array,
              required: false,
              type_options: {
                load_options_method: "groups",
              },
              ui: {
                control: :group_select,
                multiple: true,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
              },
            },
          },
          capabilities: {
            provides_current_user: true,
          },
          output_contracts: [
            {
              schema:
                Schema.merge(
                  Schema::USER_SCHEMA,
                  Schema::ACTOR_SCHEMA,
                  Schema.document(
                    "composer" => {
                      "type" => "object",
                      "properties" => COMPOSER_PROPERTIES,
                    },
                    "topic" => {
                      "type" => %w[object null],
                      "properties" => Schema::TOPIC_PROPERTIES,
                    },
                  ),
                ),
            },
          ],
        )

        def self.load_options_context(context)
          case context.method_name
          when "groups"
            ::Group
              .order(:name)
              .pluck(:id, :name)
              .select { |_, name| context.matches_filter?(name) }
              .map { |id, name| { id:, name: } }
          end
        end

        def self.validate_configuration(configuration, errors)
          phrases = phrases((configuration || {}).deep_stringify_keys)

          if phrases.size > MAX_PHRASES
            errors.add(
              :base,
              I18n.t(
                "discourse_workflows.errors.composer_paused.too_many_phrases",
                max: MAX_PHRASES,
              ),
            )
          end

          phrases.each do |phrase|
            if phrase.length > MAX_PHRASE_LENGTH
              errors.add(
                :base,
                I18n.t(
                  "discourse_workflows.errors.composer_paused.phrase_too_long",
                  phrase:,
                  max: MAX_PHRASE_LENGTH,
                ),
              )
            elsif phrase_regexp(phrase).nil?
              errors.add(
                :base,
                I18n.t("discourse_workflows.errors.composer_paused.invalid_phrase", phrase:),
              )
            end
          end
        end

        def self.fires_on?(parameters, mode)
          (parameters["fire_on"].presence || PAUSE) == mode
        end

        def self.phrases(parameters)
          Array
            .wrap(parameters["phrases"])
            .filter_map { |phrase| phrase.to_s.strip.squeeze("*").presence }
            .uniq
        end

        # Regexp sources in watched word syntax, for matching in the browser.
        def self.patterns(parameters)
          phrases(parameters).filter_map { |phrase| phrase_regexp(phrase)&.source }
        end

        def self.phrase_regexp(phrase)
          return if phrase.length > MAX_PHRASE_LENGTH

          # Pauses and autosaves are frequent, so each phrase is compiled once.
          key = "#{SiteSetting.watched_words_regular_expressions}:#{phrase}"
          phrase_regexps.getset(key) { compile_phrase(phrase) || false } || nil
        end

        def self.phrase_regexps
          @phrase_regexps ||= LruRedux::ThreadSafeCache.new(1000)
        end

        def self.compile_phrase(phrase)
          regexp = Regexp.new(WordWatcher.word_to_regexp(phrase), Regexp::IGNORECASE)
          # Anyone can send draft text, so a phrase that may backtrack could tie up the server.
          return if !Regexp.linear_time?(regexp)

          regexp if MATCH_ANYTHING_SAMPLES.none? { |sample| regexp.match?(sample) }
        rescue RegexpError
          nil
        end

        def self.matched_phrases(phrases, text)
          phrases.select { |phrase| phrase_regexp(phrase)&.match?(text) }
        end

        def self.composer_actions(parameters)
          actions = Array.wrap(parameters["composer_actions"]).map(&:to_s).compact_blank
          actions.empty? ? ComposerSnapshot::ACTIONS : actions & ComposerSnapshot::ACTIONS
        end

        def self.normalized_group_ids(parameters)
          Array
            .wrap(parameters["group_ids"])
            .filter_map do |group_id|
              value = group_id.to_s
              value.to_i if value.match?(/\A\d+\z/)
            end
        end

        def self.available_to?(user, parameters)
          return false if user.blank?

          group_ids = normalized_group_ids(parameters)
          group_ids.empty? || user.in_any_groups?(group_ids)
        end

        # Everything but the phrases, which callers match separately to know which ones fired.
        def self.matches_snapshot?(parameters, snapshot)
          return false if composer_actions(parameters).exclude?(snapshot.action)
          return false if !available_to?(snapshot.user, parameters)
          return false if !matches_category?(parameters, snapshot.filter_category_id)

          snapshot.composable?
        end

        def self.matches_category?(parameters, category_id)
          category_ids = normalize_ids(parameters["category_ids"])
          return true if category_ids.empty?

          category_ids = expand_subcategory_ids(category_ids) if parameters[
            "include_subcategories"
          ] != false
          category_ids.include?(category_id)
        end

        def initialize(snapshot, matched_phrases = [])
          super(parameters: {})
          @snapshot = snapshot
          @matched_phrases = matched_phrases
        end

        def output
          user = serialize_user(@snapshot.user)

          {
            user:,
            actor: user,
            composer: @snapshot.to_h.merge(matched_phrases: @matched_phrases),
            topic: @snapshot.topic && serialize_topic_list_item(@snapshot.topic),
          }
        end
      end
    end
  end
end
