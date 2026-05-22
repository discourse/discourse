# frozen_string_literal: true

class Admin::CommandCenter::SuspendUserPreview
  include Service::Base

  SUPPORTED_INTENT = "suspend_user"
  DEFAULT_CONFIDENCE = 0.9
  MAX_REASON_LENGTH = 300
  USERNAME_PATTERN = /[a-z0-9_.-]+/i

  params do
    attribute :command, :string

    validates :command, presence: true, length: { maximum: 500 }
  end

  step :parse_command
  step :ensure_supported_intent
  model :user
  policy :can_suspend_user
  step :build_payload

  def self.candidates_for(username)
    User
      .real
      .where("username_lower LIKE ?", "#{User.normalize_username(username)}%")
      .order(:username_lower)
      .limit(5)
      .pluck(:id, :username)
      .map { |id, candidate_username| { id:, username: candidate_username } }
  end

  def self.normalize_duration_text(duration)
    duration = duration.to_s.strip
    return if duration.blank?

    if (match = duration.match(/\A(?<amount>\d+|an?|one)\s+(?<unit>hour|day|week|month)s?\z/i))
      amount = match[:amount]
      numeric_amount = %w[a an one].include?(amount.downcase) ? 1 : amount.to_i
      return "#{amount} #{match[:unit].pluralize(numeric_amount)}"
    end

    return duration if duration.match?(/\Auntil\s+\d{4}-\d{2}-\d{2}\z/i)

    nil
  end

  private

  def parse_command(params:, guardian:)
    command = params.command.to_s.strip
    parsed_command = deterministic_parse(command) || llm_parse(command, guardian)

    return fail!("I could not identify a supported admin action.") if parsed_command.blank?

    parsed_command[:username] = parsed_command[:username].to_s.delete_prefix("@")
    return fail!("I could not identify which user to suspend.") if parsed_command[:username].blank?

    context[:parsed_command] = parsed_command
  end

  def ensure_supported_intent(parsed_command:)
    return if parsed_command[:intent] == SUPPORTED_INTENT

    fail!("Only suspend-user commands are supported in this POC.")
  end

  def fetch_user(parsed_command:)
    User.find_by_username(parsed_command[:username])
  end

  def can_suspend_user(guardian:, user:)
    guardian.can_suspend?(user)
  end

  def build_payload(user:, parsed_command:)
    context[:payload] = preview_payload(user, parsed_command)
  end

  def deterministic_parse(command)
    match =
      command.match(
        /\b(?:please\s+)?suspend\s+(?:user\s+)?@?(?<username>#{USERNAME_PATTERN.source})\b/i,
      )
    return if match.blank?

    {
      intent: SUPPORTED_INTENT,
      username: match[:username],
      duration: extract_duration_text(command),
      reason: extract_reason(command),
      message: nil,
      confidence: DEFAULT_CONFIDENCE,
      source: "deterministic",
    }
  end

  def llm_parse(command, guardian)
    return if !llm_available?

    response =
      llm.generate(
        llm_prompt(command),
        user: guardian.user,
        feature_name: "admin_command_center",
        temperature: 0.1,
        max_tokens: 200,
      )
    parsed = parse_json(response)
    return if parsed.blank?

    {
      intent: parsed["intent"].to_s,
      username: parsed["username"].to_s,
      duration: self.class.normalize_duration_text(parsed["duration"]),
      reason: parsed["reason"].presence,
      message: parsed["message"].presence,
      confidence: parsed["confidence"].to_f.clamp(0.0, 1.0),
      source: "llm",
    }
  rescue StandardError => e
    Rails.logger.warn("Admin command center LLM parse failed: #{e.class}: #{e.message}")
    nil
  end

  def llm_available?
    defined?(DiscourseAi::Completions::Llm) && SiteSetting.respond_to?(:discourse_ai_enabled) &&
      SiteSetting.discourse_ai_enabled && SiteSetting.ai_default_llm_model.present?
  end

  def llm
    DiscourseAi::Completions::Llm.proxy(SiteSetting.ai_default_llm_model)
  end

  def llm_prompt(command)
    <<~PROMPT
      Parse this admin command into JSON. Return valid JSON only.

      Supported intent:
      - suspend_user

      Schema:
      {
        "intent": "suspend_user",
        "username": "username without @",
        "duration": "optional duration such as 7 days, 24 hours, 1 week",
        "reason": "optional short reason",
        "message": "optional message to the user",
        "confidence": 0.0
      }

      If the command is not a request to suspend a user, set intent to "unsupported".

      Command: #{command}
    PROMPT
  end

  def parse_json(response)
    text = Array(response).join.strip
    text = text.gsub(/\A```(?:json)?\s*/i, "").gsub(/\s*```\z/, "")
    JSON.parse(text)
  rescue JSON::ParserError
    nil
  end

  def extract_duration_text(command)
    duration_match =
      command.match(/\bfor\s+(?<amount>\d+|an?|one)\s+(?<unit>hour|day|week|month)s?\b/i)
    if duration_match
      amount = duration_match[:amount]
      numeric_amount = %w[a an one].include?(amount.downcase) ? 1 : amount.to_i
      return self.class.normalize_duration_text("#{amount} #{duration_match[:unit]}")
    end

    until_match = command.match(/\buntil\s+(?<date>\d{4}-\d{2}-\d{2})\b/i)
    return "until #{until_match[:date]}" if until_match

    nil
  end

  def extract_reason(command)
    reason = command[/\b(?:because|due to|reason:)\s+(?<reason>.+)\z/i, :reason]

    reason ||= command[/\bfor\s+(?<reason>(?!\d+|an?\s|one\s).+)\z/i, :reason]
    reason&.strip&.truncate(MAX_REASON_LENGTH)
  end

  def suspend_until(user, duration)
    return user_next_penalty(user) if duration.blank?

    if (match = duration.match(/\Auntil\s+(?<date>\d{4}-\d{2}-\d{2})\z/i))
      parsed_date = Date.iso8601(match[:date])
      return parsed_date.end_of_day
    end

    match = duration.match(/\A(?<amount>\d+|an?|one)\s+(?<unit>hour|day|week|month)s?\z/i)
    return user_next_penalty(user) if match.blank?

    amount = %w[a an one].include?(match[:amount].downcase) ? 1 : match[:amount].to_i
    amount.public_send(match[:unit].pluralize).from_now
  rescue ArgumentError
    user_next_penalty(user)
  end

  def user_next_penalty(user)
    step_number = penalty_counts_payload(user)[:total]
    steps = SiteSetting.penalty_step_hours.split("|")
    step_number = [step_number, steps.length].min

    Integer(steps[step_number], 10).hours.from_now
  rescue StandardError
    24.hours.from_now
  end

  def preview_payload(user, parsed)
    until_date = suspend_until(user, parsed[:duration])
    reason = parsed[:reason].presence

    {
      intent: SUPPORTED_INTENT,
      parser: {
        source: parsed[:source],
        confidence: parsed[:confidence],
      },
      user: user_payload(user),
      context: user_context(user),
      suspension: {
        suspend_until: until_date.iso8601,
        duration: duration_label(parsed[:duration], until_date),
        reason: reason,
        message: default_message(parsed[:message].presence, reason),
      },
    }
  end

  def user_payload(user)
    {
      id: user.id,
      username: user.username,
      name: user.name,
      avatar_template: user.avatar_template,
      admin: user.admin?,
      moderator: user.moderator?,
      active: user.active?,
      suspended: user.suspended?,
      silenced: user.silenced?,
    }
  end

  def user_context(user)
    {
      trust_level: user.trust_level,
      created_at: user.created_at&.iso8601,
      last_seen_at: user.last_seen_at&.iso8601,
      post_count: user.post_count,
      topic_count: user.topic_count,
      flags_received_count: user.flags_received_count,
      warnings_received_count: user.warnings_received_count,
      penalty_counts: penalty_counts_payload(user),
    }
  end

  def penalty_counts_payload(user)
    penalty_counts = TrustLevel3Requirements.new(user).penalty_counts

    {
      silenced: penalty_counts.silenced,
      suspended: penalty_counts.suspended,
      total: penalty_counts.total,
    }
  end

  def duration_label(duration, until_date)
    duration.presence || "until #{I18n.l(until_date.to_date, format: :long)}"
  end

  def default_message(parsed_message, reason)
    return if SiteSetting.hide_suspension_reasons
    return parsed_message if parsed_message.present?
    return if reason.blank?

    "Your account has been temporarily suspended. Reason: #{reason}"
  end
end
