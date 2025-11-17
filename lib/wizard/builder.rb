# frozen_string_literal: true

class Wizard
  class Builder
    WIZARD_FONTS = %w[lato inter montserrat open_sans poppins roboto]

    def initialize(user)
      @wizard = Wizard.new(user)
    end

    def build
      return @wizard unless SiteSetting.wizard_enabled? && @wizard.user.try(:staff?)

      append_setup_step

      DiscourseEvent.trigger(:build_wizard, @wizard)
      @wizard
    end

    protected

    def append_setup_step
      @wizard.append_step("setup") do |step|
        step.emoji = "rocket"

        step.add_field(
          id: "title",
          type: "text",
          required: true,
          value: SiteSetting.title == SiteSetting.defaults[:title] ? "" : SiteSetting.title,
        )

        step.add_field(
          id: "default_locale",
          type: "dropdown",
          required: false,
          value: SiteSetting.default_locale,
        )

        step.add_field(
          id: "login_required",
          type: "radio",
          value: SiteSetting.login_required ? "private" : "public",
        ) do |field|
          field.add_choice("public")
          field.add_choice("private")
        end

        step.add_field(
          id: "invite_only",
          type: "radio",
          value: SiteSetting.invite_only ? "invite_only" : "sign_up",
        ) do |field|
          field.add_choice("sign_up")
          field.add_choice("invite_only")
        end

        step.add_field(
          id: "must_approve_users",
          type: "radio",
          value: SiteSetting.must_approve_users ? "yes" : "no",
        ) do |field|
          field.add_choice("no")
          field.add_choice("yes")
        end

        step.on_update do |updater|
          updater.ensure_changed(:title)

          updater.apply_settings(:title) if updater.errors.blank?

          old_locale = SiteSetting.default_locale
          updater.apply_setting(:default_locale)

          if old_locale != updater.fields[:default_locale]
            Scheduler::Defer.later "Reseed" do
              SeedData::Categories.with_default_locale.update(skip_changed: true)
              SeedData::Topics.with_default_locale.update(skip_changed: true)
            end
          end

          updater.update_setting(:login_required, updater.fields[:login_required] == "private")
          updater.update_setting(:invite_only, updater.fields[:invite_only] == "invite_only")
          updater.update_setting(:must_approve_users, updater.fields[:must_approve_users] == "yes")
        end
      end
    end

    def replace_setting_value(updater, raw, field_name)
      old_value = SiteSetting.get(field_name)
      old_value = field_name if old_value.blank?

      new_value = updater.fields[field_name.to_sym]
      new_value = field_name if new_value.blank?

      raw.gsub!("<ins>#{old_value}</ins>", new_value) || raw.gsub!(old_value, new_value)
    end
  end
end
