# frozen_string_literal: true

class AiPersona < ActiveRecord::Base
  # TODO remove this line 01-10-2025
  self.ignored_columns = %i[default_llm question_consolidator_llm]

  # places a hard limit, so per site we cache a maximum of 500 classes
  MAX_PERSONAS_PER_SITE = 500

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :system_prompt, presence: true, length: { maximum: 10_000_000 }
  validate :system_persona_unchangeable, on: :update, if: :system
  validate :chat_preconditions
  validate :allowed_seeded_model, if: :default_llm_id
  validate :well_formated_examples
  validates :max_context_posts, numericality: { greater_than: 0 }, allow_nil: true
  # leaves some room for growth but sets a maximum to avoid memory issues
  # we may want to revisit this in the future
  validates :vision_max_pixels, numericality: { greater_than: 0, maximum: 4_000_000 }

  validates :rag_chunk_tokens, numericality: { greater_than: 0, maximum: 50_000 }
  validates :rag_chunk_overlap_tokens, numericality: { greater_than: -1, maximum: 200 }
  validates :rag_conversation_chunks, numericality: { greater_than: 0, maximum: 1000 }
  validates :forced_tool_count, numericality: { greater_than: -2, maximum: 100_000 }

  validate :tools_can_not_be_duplicated

  has_many :rag_document_fragments, dependent: :destroy, as: :target

  belongs_to :created_by, class_name: "User"
  belongs_to :user

  belongs_to :default_llm, class_name: "LlmModel"
  belongs_to :question_consolidator_llm, class_name: "LlmModel"
  belongs_to :rag_llm_model, class_name: "LlmModel"

  has_many :upload_references, as: :target, dependent: :destroy
  has_many :uploads, through: :upload_references

  before_destroy :ensure_not_system
  before_update :regenerate_rag_fragments

  def self.persona_cache
    @persona_cache ||= ::DiscourseAi::MultisiteHash.new("persona_cache")
  end

  scope :ordered, -> { order("priority DESC, lower(name) ASC") }

  def self.all_personas(enabled_only: true)
    persona_cache[:value] ||= AiPersona
      .ordered
      .all
      .limit(MAX_PERSONAS_PER_SITE)
      .map(&:class_instance)

    if enabled_only
      persona_cache[:value].select { |p| p.enabled }
    else
      persona_cache[:value]
    end
  end

  def self.persona_users(user: nil)
    persona_users =
      persona_cache[:persona_users] ||= AiPersona
        .where(enabled: true)
        .joins(:user)
        .map do |persona|
          {
            id: persona.id,
            user_id: persona.user_id,
            username: persona.user.username_lower,
            allowed_group_ids: persona.allowed_group_ids,
            default_llm_id: persona.default_llm_id,
            force_default_llm: persona.force_default_llm,
            allow_chat_channel_mentions: persona.allow_chat_channel_mentions,
            allow_chat_direct_messages: persona.allow_chat_direct_messages,
            allow_topic_mentions: persona.allow_topic_mentions,
            allow_personal_messages: persona.allow_personal_messages,
          }
        end

    if user
      persona_users.select { |persona_user| user.in_any_groups?(persona_user[:allowed_group_ids]) }
    else
      persona_users
    end
  end

  def self.allowed_modalities(
    user: nil,
    allow_chat_channel_mentions: false,
    allow_chat_direct_messages: false,
    allow_topic_mentions: false,
    allow_personal_messages: false
  )
    index =
      "modality-#{allow_chat_channel_mentions}-#{allow_chat_direct_messages}-#{allow_topic_mentions}-#{allow_personal_messages}"

    personas =
      persona_cache[index.to_sym] ||= persona_users.select do |persona|
        next true if allow_chat_channel_mentions && persona[:allow_chat_channel_mentions]
        next true if allow_chat_direct_messages && persona[:allow_chat_direct_messages]
        next true if allow_topic_mentions && persona[:allow_topic_mentions]
        next true if allow_personal_messages && persona[:allow_personal_messages]
        false
      end

    if user
      personas.select { |u| user.in_any_groups?(u[:allowed_group_ids]) }
    else
      personas
    end
  end

  after_commit :bump_cache

  def bump_cache
    self.class.persona_cache.flush!
  end

  def tools_can_not_be_duplicated
    return unless tools.is_a?(Array)

    seen_tools = Set.new

    custom_tool_ids = Set.new
    builtin_tool_names = Set.new

    tools.each do |tool|
      inner_name, _, _ = tool.is_a?(Array) ? tool : [tool, nil]

      if inner_name.start_with?("custom-")
        custom_tool_ids.add(inner_name.split("-", 2).last.to_i)
      else
        builtin_tool_names.add(inner_name.downcase)
      end

      if seen_tools.include?(inner_name)
        errors.add(:tools, I18n.t("discourse_ai.ai_bot.personas.cannot_have_duplicate_tools"))
        break
      else
        seen_tools.add(inner_name)
      end
    end

    return if errors.any?

    # Checking if there are any duplicate tool_names between custom and builtin tools
    if builtin_tool_names.present? && custom_tool_ids.present?
      AiTool
        .where(id: custom_tool_ids)
        .pluck(:tool_name)
        .each do |tool_name|
          if builtin_tool_names.include?(tool_name.downcase)
            errors.add(:tools, I18n.t("discourse_ai.ai_bot.personas.cannot_have_duplicate_tools"))
            break
          end
        end
    end
  end

  def class_instance
    attributes = %i[
      id
      user_id
      system
      mentionable
      default_llm_id
      max_context_posts
      vision_enabled
      vision_max_pixels
      rag_conversation_chunks
      question_consolidator_llm_id
      allow_chat_channel_mentions
      allow_chat_direct_messages
      allow_topic_mentions
      allow_personal_messages
      force_default_llm
      name
      description
      allowed_group_ids
      tool_details
      enabled
    ]

    instance_attributes = {}
    attributes.each do |attr|
      value = self.read_attribute(attr)
      instance_attributes[attr] = value
    end

    instance_attributes[:username] = user&.username_lower

    options = {}
    force_tool_use = []

    tools =
      self.tools.filter_map do |element|
        klass = nil

        element = [element] if element.is_a?(String)

        inner_name, current_options, should_force_tool_use =
          element.is_a?(Array) ? element : [element, nil]

        if inner_name.start_with?("custom-")
          custom_tool_id = inner_name.split("-", 2).last.to_i
          if AiTool.exists?(id: custom_tool_id, enabled: true)
            klass = DiscourseAi::Personas::Tools::Custom.class_instance(custom_tool_id)
          end
        else
          inner_name = inner_name.gsub("Tool", "")
          inner_name = "List#{inner_name}" if %w[Categories Tags].include?(inner_name)

          begin
            klass = "DiscourseAi::Personas::Tools::#{inner_name}".constantize
            options[klass] = current_options if current_options
          rescue StandardError
          end
        end

        force_tool_use << klass if should_force_tool_use
        klass
      end

    persona_class = DiscourseAi::Personas::Persona.system_personas_by_id[self.id]
    if persona_class
      return(
        # we need a new copy so we don't leak information
        # across sites
        Class.new(persona_class) do
          # required for localization
          define_singleton_method(:to_s) { persona_class.to_s }
          instance_attributes.each do |key, value|
            # description/name are localized
            define_singleton_method(key) { value } if key != :description && key != :name
          end
          define_method(:options) { options }
        end
      )
    end

    ai_persona_id = self.id

    Class.new(DiscourseAi::Personas::Persona) do
      instance_attributes.each { |key, value| define_singleton_method(key) { value } }

      define_singleton_method(:to_s) do
        "#<#{self.class.name} @name=#{name} @allowed_group_ids=#{allowed_group_ids.join(",")}>"
      end

      define_singleton_method(:inspect) { to_s }

      define_method(:initialize) do |*args, **kwargs|
        @ai_persona = AiPersona.find_by(id: ai_persona_id)
        super(*args, **kwargs)
      end

      define_method(:tools) { tools }
      define_method(:force_tool_use) { force_tool_use }
      define_method(:forced_tool_count) { @ai_persona&.forced_tool_count }
      define_method(:options) { options }
      define_method(:temperature) { @ai_persona&.temperature }
      define_method(:top_p) { @ai_persona&.top_p }
      define_method(:system_prompt) { @ai_persona&.system_prompt || "You are a helpful bot." }
      define_method(:uploads) { @ai_persona&.uploads }
      define_method(:response_format) { @ai_persona&.response_format }
      define_method(:examples) { @ai_persona&.examples }
    end
  end

  FIRST_PERSONA_USER_ID = -1200

  def create_user!
    raise "User already exists" if user_id && User.exists?(user_id)

    # find the first id smaller than FIRST_USER_ID that is not taken
    id = nil

    id = DB.query_single(<<~SQL, FIRST_PERSONA_USER_ID, FIRST_PERSONA_USER_ID - 200).first
        WITH seq AS (
          SELECT generate_series(?, ?, -1) AS id
          )
        SELECT seq.id FROM seq
        LEFT JOIN users ON users.id = seq.id
        WHERE users.id IS NULL
        ORDER BY seq.id DESC
      SQL

    id = DB.query_single(<<~SQL).first if id.nil?
        SELECT min(id) - 1 FROM users
      SQL

    # note .invalid is a reserved TLD which will route nowhere
    user =
      User.new(
        email: "#{SecureRandom.hex}@does-not-exist.invalid",
        name: name.titleize,
        username: UserNameSuggester.suggest(name + "_bot"),
        active: true,
        approved: true,
        trust_level: TrustLevel[4],
        id: id,
      )
    user.save!(validate: false)

    update!(user_id: user.id)
    user
  end

  def regenerate_rag_fragments
    if rag_chunk_tokens_changed? || rag_chunk_overlap_tokens_changed?
      RagDocumentFragment.where(target: self).delete_all
    end
  end

  def features
    DiscourseAi::Configuration::Feature.find_features_using(persona_id: id)
  end

  private

  def chat_preconditions
    if (
         allow_chat_channel_mentions || allow_chat_direct_messages || allow_topic_mentions ||
           force_default_llm
       ) && !default_llm_id
      errors.add(:default_llm, I18n.t("discourse_ai.ai_bot.personas.default_llm_required"))
    end
  end

  def system_persona_unchangeable
    error_msg = I18n.t("discourse_ai.ai_bot.personas.cannot_edit_system_persona")

    if top_p_changed? || temperature_changed? || system_prompt_changed? || name_changed? ||
         description_changed?
      errors.add(:base, error_msg)
    elsif tools_changed?
      old_tools = tools_change[0]
      new_tools = tools_change[1]

      old_tool_names = old_tools.map { |t| t.is_a?(Array) ? t[0] : t }.to_set
      new_tool_names = new_tools.map { |t| t.is_a?(Array) ? t[0] : t }.to_set

      errors.add(:base, error_msg) if old_tool_names != new_tool_names
    elsif response_format_changed?
      old_format = response_format_change[0].map { |f| f["key"] }.to_set
      new_format = response_format_change[1].map { |f| f["key"] }.to_set

      errors.add(:base, error_msg) if old_format != new_format
    elsif examples_changed?
      old_examples = examples_change[0].flatten.to_set
      new_examples = examples_change[1].flatten.to_set

      errors.add(:base, error_msg) if old_examples != new_examples
    end
  end

  def ensure_not_system
    if system
      errors.add(:base, I18n.t("discourse_ai.ai_bot.personas.cannot_delete_system_persona"))
      throw :abort
    end
  end

  def allowed_seeded_model
    return if default_llm_id.blank?

    return if default_llm.nil?
    return if !default_llm.seeded?

    return if SiteSetting.ai_bot_allowed_seeded_models_map.include?(default_llm.id.to_s)

    errors.add(:default_llm, I18n.t("discourse_ai.llm.configuration.invalid_seeded_model"))
  end

  def well_formated_examples
    return if examples.blank?

    if examples.is_a?(Array) &&
         examples.all? { |e| e.is_a?(Array) && e.length == 2 && e.all?(&:present?) }
      return
    end

    errors.add(:examples, I18n.t("discourse_ai.personas.malformed_examples"))
  end
end

# == Schema Information
#
# Table name: ai_personas
#
#  id                           :bigint           not null, primary key
#  name                         :string(100)      not null
#  description                  :string(2000)     not null
#  system_prompt                :string(10000000) not null
#  allowed_group_ids            :integer          default([]), not null, is an Array
#  created_by_id                :integer
#  enabled                      :boolean          default(TRUE), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  system                       :boolean          default(FALSE), not null
#  priority                     :boolean          default(FALSE), not null
#  temperature                  :float
#  top_p                        :float
#  user_id                      :integer
#  max_context_posts            :integer
#  vision_enabled               :boolean          default(FALSE), not null
#  vision_max_pixels            :integer          default(1048576), not null
#  rag_chunk_tokens             :integer          default(374), not null
#  rag_chunk_overlap_tokens     :integer          default(10), not null
#  rag_conversation_chunks      :integer          default(10), not null
#  tool_details                 :boolean          default(TRUE), not null
#  tools                        :json             not null
#  forced_tool_count            :integer          default(-1), not null
#  allow_chat_channel_mentions  :boolean          default(FALSE), not null
#  allow_chat_direct_messages   :boolean          default(FALSE), not null
#  allow_topic_mentions         :boolean          default(FALSE), not null
#  allow_personal_messages      :boolean          default(TRUE), not null
#  force_default_llm            :boolean          default(FALSE), not null
#  rag_llm_model_id             :bigint
#  default_llm_id               :bigint
#  question_consolidator_llm_id :bigint
#  response_format              :jsonb
#  examples                     :jsonb
#
# Indexes
#
#  index_ai_personas_on_name  (name) UNIQUE
#
