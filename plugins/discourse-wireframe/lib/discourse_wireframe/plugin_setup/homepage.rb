# frozen_string_literal: true

module DiscourseWireframe
  module PluginSetup
    # Opts the resolved theme's homepage into the blocks layout. Core consults
    # the `custom_homepage_enabled` modifier from `HomepageHelper.resolve` on
    # every `/` request; the answer here comes from the `themeable`
    # `custom_homepage` site setting, so it is a per-parent-theme
    # decision made by an admin rather than site-wide state. It only applies once
    # the theme has a homepage layout; without one visitors keep the default and
    # admins get the empty homepage that invites them to build one.
    module Homepage
      def self.apply(plugin)
        # The keyword-style args at the `apply_modifier` call site arrive as one
        # trailing positional Hash (the registry's dispatch has no kwargs), so
        # the block MUST NOT declare keyword parameters.
        plugin.register_modifier(:custom_homepage_enabled) do |enabled, opts|
          if enabled
            enabled
          else
            # The resolved theme id can legitimately be missing: bare
            # `HomepageHelper.resolve` calls in core, or a guardian that
            # disallows every theme. A themeable read without a theme raises,
            # so fall back to the upstream answer instead.
            theme_id = (opts || {})[:request]&.env&.[](:resolved_theme_id)
            if theme_id
              SiteSetting.custom_homepage(theme_id: theme_id) &&
                (
                  DiscourseWireframe::HomepageLayout.published?(theme_id) ||
                    CurrentUser.lookup_from_env(opts[:request].env)&.admin?
                )
            else
              enabled
            end
          end
        end
      end
    end
  end
end
