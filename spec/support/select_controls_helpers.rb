# frozen_string_literal: true

module SelectControlsHelpers
  # Pins `enable_new_select_controls` for an example group, so a migrating select family's
  # flag-off and flag-on specs keep their mode when the change is promoted. An assigned value is
  # stored even when it equals the default, which is what makes the off pin survive promotion
  # (spec/integrity/select_controls_pin_spec.rb).
  def with_select_controls(enabled)
    before { SiteSetting.enable_new_select_controls = enabled }
  end
end
