# frozen_string_literal: true

class DsaStatementRecorder
  def self.record(reviewable:, result:)
    new(reviewable:, result:).record
  end

  def initialize(reviewable:, result:)
    @reviewable = reviewable
    @result = result
  end

  def record
    restriction_groups.each do |restrictions|
      statement_id = SecureRandom.uuid
      DsaStatementOfRecord.create!(
        id: statement_id,
        reviewable_id: @reviewable.id,
        payload: payload(restrictions).merge("puid" => statement_id),
      )
    end
  end

  private

  VISIBILITY = {
    removed: "DECISION_VISIBILITY_CONTENT_REMOVED",
    disabled: "DECISION_VISIBILITY_CONTENT_DISABLED",
    demoted: "DECISION_VISIBILITY_CONTENT_DEMOTED",
    interaction_restricted: "DECISION_VISIBILITY_CONTENT_INTERACTION_RESTRICTED",
    edited: "DECISION_VISIBILITY_OTHER",
    audience_restricted: "DECISION_VISIBILITY_OTHER",
  }.freeze
  private_constant :VISIBILITY

  def restriction_groups
    accounts, contents =
      @result.restrictions.partition { |restriction| restriction.content_kind == :account }
    groups = contents.group_by { |restriction| restriction.created_at.to_date }.values
    accounts.each do |account|
      group =
        groups.find do |candidates|
          related = candidates.any? { |candidate| candidate.account_id == account.account_id }
          same_content_date = candidates.first.created_at.to_date == account.created_at.to_date
          compatible =
            candidates.all? do |candidate|
              candidate.content_kind != :account ||
                (candidate.kind == :silenced) != (account.kind == :silenced) ||
                (
                  candidate.kind == account.kind &&
                    candidate.expires_at&.to_date == account.expires_at&.to_date
                )
            end
          (related || same_content_date) && compatible
        end
      if group
        group << account
      else
        groups << [account]
      end
    end
    groups
  end

  def payload(restrictions)
    content = restrictions.reject { |restriction| restriction.content_kind == :account }
    subjects = content.presence || restrictions
    types = subjects.flat_map { |subject| content_types(subject) }.uniq
    values = {
      "content_type" => types,
      "content_date" => subjects.first.created_at.to_date.iso8601,
      "application_date" => Date.current.iso8601,
    }
    if types.include?("CONTENT_TYPE_OTHER")
      values["content_type_other"] = content.empty? ? "User account" : "User supplied content"
    end
    languages = subjects.map { |subject| language(subject.locale) }.uniq
    values["content_language"] = languages.first if languages.one? && languages.first

    visibility = restrictions.filter_map { |restriction| VISIBILITY[restriction.kind] }.uniq
    values["decision_visibility"] = visibility if visibility.present?
    descriptions =
      restrictions
        .filter_map do |restriction|
          case restriction.kind
          when :edited
            "Content edited"
          when :audience_restricted
            "Content audience restricted"
          end
        end
        .uniq
    values["decision_visibility_other"] = descriptions.join("; ") if descriptions.present?

    restrictions.each do |restriction|
      case restriction.kind
      when :suspended
        values["decision_account"] = "DECISION_ACCOUNT_SUSPENDED"
        values["end_date_account_restriction"] = restriction
          .expires_at
          .to_date
          .iso8601 if restriction.expires_at
      when :terminated
        values["decision_account"] = "DECISION_ACCOUNT_TERMINATED"
      when :silenced
        values["decision_provision"] = "DECISION_PROVISION_PARTIAL_SUSPENSION"
        values["end_date_service_restriction"] = restriction
          .expires_at
          .to_date
          .iso8601 if restriction.expires_at
      end
    end
    if content.present? && content.all?(&:expires_at)
      values["end_date_visibility_restriction"] = content.map(&:expires_at).max.to_date.iso8601
    end
    values["automated_detection"] = "Yes" if @result.automated_detection
    if @result.decision_automation
      values["automated_decision"] = {
        full: "AUTOMATED_DECISION_FULLY",
        partial: "AUTOMATED_DECISION_PARTIALLY",
      }.fetch(@result.decision_automation)
    end
    values
  end

  def content_types(subject)
    return ["CONTENT_TYPE_OTHER"] if subject.content_kind == :account
    return ["CONTENT_TYPE_IMAGE"] if subject.content_kind == :image

    cooked = subject.cooked.presence || PrettyText.cook(subject.raw.to_s)
    document = Nokogiri::HTML5.fragment(cooked)
    types = subject.attachment_types.map { |type| "CONTENT_TYPE_#{type.to_s.upcase}" }
    types << "CONTENT_TYPE_IMAGE" if document.at_css("img")
    types << "CONTENT_TYPE_VIDEO" if document.at_css("video")
    types << "CONTENT_TYPE_AUDIO" if document.at_css("audio")
    types << "CONTENT_TYPE_TEXT" if document.text.strip.present?
    types.uniq.presence || ["CONTENT_TYPE_OTHER"]
  end

  def language(locale)
    code = locale.to_s.split(/[-_]/).first.to_s.upcase
    if code.match?(/\A[A-Z]{2}\z/) &&
         LocaleSiteSetting.language_names.keys.any? { |known|
           known.split("_").first.casecmp?(code)
         }
      code
    end
  end
end
