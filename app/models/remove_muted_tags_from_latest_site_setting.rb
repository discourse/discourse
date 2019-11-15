# frozen_string_literal: true

class RemoveMutedTagsFromLatestSiteSetting < EnumSiteSetting

  ALWAYS ||= "always"
  ONLY_MUTED ||= "only_muted"
  NEVER ||= "never"

  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "admin.tags.remove_muted_tags_from_latest.always", value: ALWAYS },
      { name: "admin.tags.remove_muted_tags_from_latest.only_muted", value: ONLY_MUTED },
      { name: "admin.tags.remove_muted_tags_from_latest.never", value: NEVER }
    ]
  end

  def self.translate_names?
    true
  end
end
