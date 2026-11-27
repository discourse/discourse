# frozen_string_literal: true

module DiscourseSolved::BadgeExtension
  THRESHOLD_SETTINGS = {
    "Solved 2" => :solved_badge_2_required_solutions,
    "Solved 3" => :solved_badge_3_required_solutions,
    "Solved 4" => :solved_badge_4_required_solutions,
  }.freeze

  def query
    threshold = configured_solved_threshold
    threshold ? DiscourseSolved::Queries.solved_badge_query(threshold) : super
  end

  def description
    solved_threshold_description || super
  end

  def long_description
    solved_threshold_description || super
  end

  private

  def solved_threshold_description
    threshold = configured_solved_threshold
    I18n.t("badges.solved_threshold", count: threshold) if threshold
  end

  def configured_solved_threshold
    return unless system? && (setting = THRESHOLD_SETTINGS[name])

    value = SiteSetting.public_send(setting)
    value if value != SiteSetting.defaults[setting]
  end
end
