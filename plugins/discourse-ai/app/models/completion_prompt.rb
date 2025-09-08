# frozen_string_literal: true

class CompletionPrompt < ActiveRecord::Base
  #
  # DEPRECATED.
  # TODO(roman): Remove after 06-17-25
  #

  TRANSLATE = -301
  GENERATE_TITLES = -307
  PROOFREAD = -303
  MARKDOWN_TABLE = -304
  CUSTOM_PROMPT = -305
  EXPLAIN = -306
  ILLUSTRATE_POST = -308
  DETECT_TEXT_LOCALE = -309

  enum :prompt_type, { text: 0, list: 1, diff: 2 }

  validates :messages, length: { maximum: 20 }
  validate :each_message_length

  after_commit { DiscourseAi::AiHelper::Assistant.clear_prompt_cache! }

  def self.enabled_by_name(name)
    where(enabled: true).find_by(name: name)
  end

  attr_accessor :custom_instruction

  def messages_with_input(input)
    return unless input

    user_input =
      if id == CUSTOM_PROMPT && custom_instruction.present?
        "#{custom_instruction}:\n#{input}"
      else
        input
      end

    instructions = [messages_hash[:insts], messages_hash[:post_insts].to_s].join("\n")

    prompt = DiscourseAi::Completions::Prompt.new(instructions)

    messages_hash[:examples].to_a.each do |example_pair|
      prompt.push(type: :user, content: example_pair.first)
      prompt.push(type: :model, content: example_pair.second)
    end

    prompt.push(type: :user, content: "<input>#{user_input}</input>")

    prompt
  end

  private

  def messages_hash
    @messages_hash ||= messages.symbolize_keys!
  end

  def each_message_length
    messages.each_with_index do |msg, idx|
      next if msg["content"].length <= 1000

      errors.add(:messages, I18n.t("discourse_ai.errors.prompt_message_length", idx: idx + 1))
    end
  end
end

# == Schema Information
#
# Table name: completion_prompts
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  translated_name :string
#  prompt_type     :integer          default("text"), not null
#  enabled         :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  messages        :jsonb
#  temperature     :integer
#  stop_sequences  :string           is an Array
#
# Indexes
#
#  index_completion_prompts_on_name  (name)
#
