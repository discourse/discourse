# frozen_string_literal: true

Report.add_report("users_by_trust_level") do |report|
  report.data = []

  report.modes = [:table]

  report.dates_filtering = false

  report.labels = [
    {
      property: :key,
      title: I18n.t("reports.users_by_trust_level.labels.level")
    },
    {
      property: :y,
      type: :number,
      title: I18n.t("reports.default.labels.count")
    }
  ]

  User.real.group('trust_level').count.sort.each do |level, count|
    key = TrustLevel.levels[level.to_i]
    url = Proc.new { |k| "/admin/users/list/#{k}" }
    report.data << { url: url.call(key), key: key, x: level.to_i, y: count }
  end
end
