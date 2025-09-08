# frozen_string_literal: true

require_dependency "enum_site_setting"

class AssignMailerSiteSettings < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    @values ||= [
      { name: "discourse_assign.assign_mailer.never", value: AssignMailer.levels[:never] },
      {
        name: "discourse_assign.assign_mailer.different_users",
        value: AssignMailer.levels[:different_users],
      },
      { name: "discourse_assign.assign_mailer.always", value: AssignMailer.levels[:always] },
    ]
  end

  def self.translate_names?
    true
  end
end
