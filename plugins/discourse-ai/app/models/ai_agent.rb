# frozen_string_literal: true

class AiAgent < ActiveRecord::Base
  # TODO remove tool_details from ignored_columns 01-02-2027
  self.ignored_columns = %i[tool_details]

  # places a hard limit, so per site we cache a maximum of 500 classes
  MAX_AGENTS_PER_SITE = 500

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :system_prompt, presence: true, length: { maximum: 10_000_000 }
  validate :system_agent_unchangeable, on: :update, if: :system
  validate :chat_preconditions
  validate :well_formated_examples
  validates :max_context_posts, numericality: { greater_than: 0 }, allow_nil: true
  validates :execution_mode, inclusion: { in: %w[default agentic] }
  validates :max_turn_tokens,
            numericality: {
              greater_than: 0,
              maximum: 10_000_000,
            },
            allow_nil: true
  validates :compression_threshold,
            presence: true,
            numericality: {
              greater_than_or_equal_to: 20,
              less_than_or_equal_to: 99,
            },
            if: -> { execution_mode == "agentic" }
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

  before_update :regenerate_rag_fragments
  before_destroy :ensure_not_system

  def self.agent_cache
    @agent_cache ||= DiscourseAi::MultisiteHash.new("agent_cache")
  end

  scope :ordered, -> { order("priority DESC, lower(name) ASC") }

  def self.all_agents(enabled_only: true)
    agent_cache[:value] ||= AiAgent.ordered.all.limit(MAX_AGENTS_PER_SITE).map(&:class_instance)

    if enabled_only
      agent_cache[:value].select { |p| p.enabled }
    else
      agent_cache[:value]
    end
  end

  def self.all_agent_records(enabled_only: true)
    agent_cache[:records] ||= AiAgent.ordered.includes(:user).all.limit(MAX_AGENTS_PER_SITE).to_a

    if enabled_only
      agent_cache[:records].select(&:enabled)
    else
      agent_cache[:records]
    end
  end

  def self.find_by_id_from_cache(agent_id)
    return nil if agent_id.nil?

    # Try to find in record cache first
    cached_agent = all_agent_records(enabled_only: false).find { |p| p.id == agent_id.to_i }
    return cached_agent if cached_agent

    # Fallback to database if not found in cache (e.g., in tests or if cache is stale)
    find_by(id: agent_id.to_i)
  end

  def self.agent_users(user: nil)
    agent_users =
      agent_cache[:agent_users] ||= AiAgent
        .where(enabled: true)
        .joins(:user)
        .map do |agent|
          {
            id: agent.id,
            user_id: agent.user_id,
            username: agent.user.username_lower,
            allowed_group_ids: agent.allowed_group_ids,
            default_llm_id: agent.default_llm_id,
            force_default_llm: agent.force_default_llm,
            allow_chat_channel_mentions: agent.allow_chat_channel_mentions,
            allow_chat_direct_messages: agent.allow_chat_direct_messages,
            allow_topic_mentions: agent.allow_topic_mentions,
            allow_personal_messages: agent.allow_personal_messages,
          }
        end

    if user
      agent_users.select { |agent_user| user.in_any_groups?(agent_user[:allowed_group_ids]) }
    else
      agent_users
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

    agents =
      agent_cache[index.to_sym] ||= agent_users.select do |agent|
        next true if allow_chat_channel_mentions && agent[:allow_chat_channel_mentions]
        next true if allow_chat_direct_messages && agent[:allow_chat_direct_messages]
        next true if allow_topic_mentions && agent[:allow_topic_mentions]
        next true if allow_personal_messages && agent[:allow_personal_messages]
        false
      end

    if user
      agents.select { |u| user.in_any_groups?(u[:allowed_group_ids]) }
    else
      agents
    end
  end

  after_commit :bump_cache

  def bump_cache
    self.class.agent_cache.flush!
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
        errors.add(:tools, I18n.t("discourse_ai.ai_bot.agents.cannot_have_duplicate_tools"))
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
            errors.add(:tools, I18n.t("discourse_ai.ai_bot.agents.cannot_have_duplicate_tools"))
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
      show_thinking
      enabled
      execution_mode
      max_turn_tokens
      compression_threshold
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
            klass = DiscourseAi::Agents::Tools::Custom.class_instance(custom_tool_id)
          end
        else
          inner_name = inner_name.gsub("Tool", "")
          inner_name = "List#{inner_name}" if %w[Categories Tags].include?(inner_name)

          begin
            klass = "DiscourseAi::Agents::Tools::#{inner_name}".constantize
            options[klass] = current_options if current_options
          rescue StandardError
          end
        end

        force_tool_use << klass if should_force_tool_use
        klass
      end

    agent_class = DiscourseAi::Agents::Agent.system_agents_by_id[self.id]
    if agent_class
      return(
        # we need a new copy so we don't leak information
        # across sites
        Class.new(agent_class) do
          # required for localization
          define_singleton_method(:to_s) { agent_class.to_s }
          instance_attributes.each do |key, value|
            # description/name are localized
            define_singleton_method(key) { value } if key != :description && key != :name
          end
          define_method(:options) { options }
        end
      )
    end

    ai_agent_id = self.id

    Class.new(DiscourseAi::Agents::Agent) do
      instance_attributes.each { |key, value| define_singleton_method(key) { value } }

      define_singleton_method(:to_s) do
        "#<#{self.class.name} @name=#{name} @allowed_group_ids=#{allowed_group_ids.join(",")}>"
      end

      define_singleton_method(:inspect) { to_s }

      define_method(:initialize) do |*args, **kwargs|
        @ai_agent = AiAgent.find_by(id: ai_agent_id)
        super(*args, **kwargs)
      end

      define_method(:tools) { tools }
      define_method(:force_tool_use) { force_tool_use }
      define_method(:forced_tool_count) { @ai_agent&.forced_tool_count }
      define_method(:options) { options }
      define_method(:temperature) { @ai_agent&.temperature }
      define_method(:top_p) { @ai_agent&.top_p }
      define_method(:system_prompt) { @ai_agent&.system_prompt || "You are a helpful bot." }
      define_method(:uploads) { @ai_agent&.uploads }
      define_method(:response_format) { @ai_agent&.response_format }
      define_method(:examples) { @ai_agent&.examples }
    end
  end

  FIRST_AGENT_USER_ID = -1200

  def create_user!
    raise "User already exists" if user_id && User.exists?(user_id)

    # find the first id smaller than FIRST_USER_ID that is not taken
    id = nil

    id = DB.query_single(<<~SQL, FIRST_AGENT_USER_ID, FIRST_AGENT_USER_ID - 200).first
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

  def has_image_generation_tool?
    agent_klass = class_instance.new
    agent_klass.tools.any? do |tool_klass|
      if tool_klass.respond_to?(:custom?) && tool_klass.custom?
        ai_tool = AiTool.find_by(id: tool_klass.tool_id)
        ai_tool&.image_generation_tool?
      else
        false
      end
    end
  end

  def features
    DiscourseAi::Configuration::Feature.find_features_using(agent_id: id)
  end

  private

  def chat_preconditions
    if (
         allow_chat_channel_mentions || allow_chat_direct_messages || allow_topic_mentions ||
           force_default_llm
       ) && !default_llm_id
      errors.add(:default_llm, I18n.t("discourse_ai.ai_bot.agents.default_llm_required"))
    end
  end

  def system_agent_unchangeable
    error_msg = I18n.t("discourse_ai.ai_bot.agents.cannot_edit_system_agent")

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
      errors.add(:base, I18n.t("discourse_ai.ai_bot.agents.cannot_delete_system_agent"))
      throw :abort
    end
  end

  def well_formated_examples
    return if examples.blank?

    if examples.is_a?(Array) &&
         examples.all? { |e| e.is_a?(Array) && e.length == 2 && e.all?(&:present?) }
      return
    end

    errors.add(:examples, I18n.t("discourse_ai.agents.malformed_examples"))
  end
end

# == Schema Information
#
# Table name: ai_agents
#
#  id                           :bigint           not null, primary key
#  allow_chat_channel_mentions  :boolean          default(FALSE), not null
#  allow_chat_direct_messages   :boolean          default(FALSE), not null
#  allow_personal_messages      :boolean          default(TRUE), not null
#  allow_topic_mentions         :boolean          default(FALSE), not null
#  allowed_group_ids            :integer          default([]), not null, is an Array
#  compression_threshold        :integer
#  description                  :string(2000)     not null
#  enabled                      :boolean          default(TRUE), not null
#  examples                     :jsonb
#  execution_mode               :string           default("default"), not null
#  force_default_llm            :boolean          default(FALSE), not null
#  forced_tool_count            :integer          default(-1), not null
#  max_context_posts            :integer
#  max_turn_tokens              :integer
#  name                         :string(100)      not null
#  priority                     :boolean          default(FALSE), not null
#  rag_chunk_overlap_tokens     :integer          default(10), not null
#  rag_chunk_tokens             :integer          default(374), not null
#  rag_conversation_chunks      :integer          default(10), not null
#  response_format              :jsonb
#  show_thinking                :boolean          default(TRUE), not null
#  system                       :boolean          default(FALSE), not null
#  system_prompt                :string(10000000) not null
#  temperature                  :float
#  tools                        :json             not null
#  top_p                        :float
#  vision_enabled               :boolean          default(FALSE), not null
#  vision_max_pixels            :integer          default(1048576), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  created_by_id                :integer
#  default_llm_id               :bigint
#  question_consolidator_llm_id :bigint
#  rag_llm_model_id             :bigint
#  user_id                      :integer
#
# Indexes
#
#  index_ai_agents_on_name  (name) UNIQUE
#
