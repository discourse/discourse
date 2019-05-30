# frozen_string_literal: true

Report.add_report("users_by_type") do |report|
  report.data = []

  report.modes = [:table]

  report.dates_filtering = false

  report.labels = [
    {
      property: :x,
      title: I18n.t("reports.users_by_type.labels.type")
    },
    {
      property: :y,
      type: :number,
      title: I18n.t("reports.default.labels.count")
    }
  ]

  label = Proc.new { |x| I18n.t("reports.users_by_type.xaxis_labels.#{x}") }
  url = Proc.new { |key| "/admin/users/list/#{key}" }

  admins = User.real.admins.count
  report.data << { url: url.call("admins"), icon: "shield-alt", key: "admins", x: label.call("admin"), y: admins } if admins > 0

  moderators = User.real.moderators.count
  report.data << { url: url.call("moderators"), icon: "shield-alt", key: "moderators", x: label.call("moderator"), y: moderators } if moderators > 0

  suspended = User.real.suspended.count
  report.data << { url: url.call("suspended"), icon: "ban", key: "suspended", x: label.call("suspended"), y: suspended } if suspended > 0

  silenced = User.real.silenced.count
  report.data << { url: url.call("silenced"), icon: "ban", key: "silenced", x: label.call("silenced"), y: silenced } if silenced > 0
end
