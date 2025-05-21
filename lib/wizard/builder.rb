# frozen_string_literal: true

class Wizard
  class Builder
    WIZARD_FONTS = %w[lato inter montserrat open_sans poppins roboto]

    def initialize(user)
      @wizard = Wizard.new(user)
    end

    def build
      return @wizard unless SiteSetting.wizard_enabled? && @wizard.user.try(:staff?)

      append_introduction_step
      append_privacy_step
      append_ready_step

      DiscourseEvent.trigger(:build_wizard, @wizard)
      @wizard
    end

    protected

    def append_introduction_step
      @wizard.append_step("introduction") do |step|
        step.emoji = "wave"
        step.description_vars = { base_path: Discourse.base_path }

        step.add_field(
          id: "title",
          type: "text",
          required: true,
          value: SiteSetting.title == SiteSetting.defaults[:title] ? "" : SiteSetting.title,
        )
        step.add_field(
          id: "site_description",
          type: "text",
          required: false,
          value: SiteSetting.site_description,
        )

        languages =
          step.add_field(
            id: "default_locale",
            type: "dropdown",
            required: false,
            value: SiteSetting.default_locale,
          )

        LocaleSiteSetting.values.each do |locale|
          languages.add_choice(locale[:value], label: locale[:name])
        end

        step.on_update do |updater|
          updater.ensure_changed(:title)

          updater.apply_settings(:title, :site_description) if updater.errors.blank?

          old_locale = SiteSetting.default_locale
          updater.apply_setting(:default_locale)

          if old_locale != updater.fields[:default_locale]
            Scheduler::Defer.later "Reseed" do
              SeedData::Categories.with_default_locale.update(skip_changed: true)
              SeedData::Topics.with_default_locale.update(skip_changed: true)
            end

            updater.refresh_required = true
          end
        end
      end
    end

    def append_privacy_step
      @wizard.append_step("privacy") do |step|
        step.emoji = "hugs"

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
          updater.update_setting(:login_required, updater.fields[:login_required] == "private")
          updater.update_setting(:invite_only, updater.fields[:invite_only] == "invite_only")
          updater.update_setting(:must_approve_users, updater.fields[:must_approve_users] == "yes")
        end
      end
    end

    def append_ready_step
      @wizard.append_step("ready") do |step|
        # no form on this page, just info.
        step.emoji = "rocket"
      end
    end

    def replace_setting_value(updater, raw, field_name)
      old_value = SiteSetting.get(field_name)
      old_value = field_name if old_value.blank?

      new_value = updater.fields[field_name.to_sym]
      new_value = field_name if new_value.blank?

      raw.gsub!("<ins>#{old_value}</ins>", new_value) || raw.gsub!(old_value, new_value)
    end

    def reserved_usernames
      @reserved_usernames ||= SiteSetting.defaults[:reserved_usernames].split("|")
    end

    def update_tos
      tos_post = Post.find_by(topic_id: SiteSetting.tos_topic_id, post_number: 1)

      if tos_post.present?
        raw = tos_post.raw.dup

        yield(raw)

        revisor = PostRevisor.new(tos_post)
        revisor.revise!(@wizard.user, raw: raw)
      end
    end
  end
end
