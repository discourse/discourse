# frozen_string_literal: true

Report.add_report("moderators_activity") do |report|
  report.labels = [
    {
      type: :user,
      properties: {
        username: :username,
        id: :user_id,
        avatar: :user_avatar_template,
      },
      title: I18n.t("reports.moderators_activity.labels.moderator"),
    },
    {
      property: :flag_count,
      type: :number,
      title: I18n.t("reports.moderators_activity.labels.flag_count")
    },
    {
      type: :seconds,
      property: :time_read,
      title: I18n.t("reports.moderators_activity.labels.time_read")
    },
    {
      property: :topic_count,
      type: :number,
      title: I18n.t("reports.moderators_activity.labels.topic_count")
    },
    {
      property: :pm_count,
      type: :number,
      title: I18n.t("reports.moderators_activity.labels.pm_count")
    },
    {
      property: :post_count,
      type: :number,
      title: I18n.t("reports.moderators_activity.labels.post_count")
    },
    {
      property: :revision_count,
      type: :number,
      title: I18n.t("reports.moderators_activity.labels.revision_count")
    }
  ]

  report.modes = [:table]
  report.data = []

  query = <<~SQL
  WITH mods AS (
  SELECT
  id AS user_id,
  username_lower AS username,
  uploaded_avatar_id
  FROM users u
  WHERE u.moderator = 'true'
  AND u.id > 0
  ),
  time_read AS (
  SELECT SUM(uv.time_read) AS time_read,
  uv.user_id
  FROM mods m
  JOIN user_visits uv
  ON m.user_id = uv.user_id
  WHERE uv.visited_at >= '#{report.start_date}'
  AND uv.visited_at <= '#{report.end_date}'
  GROUP BY uv.user_id
  ),
  flag_count AS (
      WITH period_actions AS (
      SELECT agreed_by_id,
      disagreed_by_id
      FROM post_actions
      WHERE post_action_type_id IN (#{PostActionType.flag_types_without_custom.values.join(',')})
      AND created_at >= '#{report.start_date}'
      AND created_at <= '#{report.end_date}'
      ),
      agreed_flags AS (
      SELECT pa.agreed_by_id AS user_id,
      COUNT(*) AS flag_count
      FROM mods m
      JOIN period_actions pa
      ON pa.agreed_by_id = m.user_id
      GROUP BY agreed_by_id
      ),
      disagreed_flags AS (
      SELECT pa.disagreed_by_id AS user_id,
      COUNT(*) AS flag_count
      FROM mods m
      JOIN period_actions pa
      ON pa.disagreed_by_id = m.user_id
      GROUP BY disagreed_by_id
      )
  SELECT
  COALESCE(af.user_id, df.user_id) AS user_id,
  COALESCE(af.flag_count, 0) + COALESCE(df.flag_count, 0) AS flag_count
  FROM agreed_flags af
  FULL OUTER JOIN disagreed_flags df
  ON df.user_id = af.user_id
  ),
  revision_count AS (
  SELECT pr.user_id,
  COUNT(*) AS revision_count
  FROM mods m
  JOIN post_revisions pr
  ON pr.user_id = m.user_id
  JOIN posts p
  ON p.id = pr.post_id
  WHERE pr.created_at >= '#{report.start_date}'
  AND pr.created_at <= '#{report.end_date}'
  AND p.user_id <> pr.user_id
  GROUP BY pr.user_id
  ),
  topic_count AS (
  SELECT t.user_id,
  COUNT(*) AS topic_count
  FROM mods m
  JOIN topics t
  ON t.user_id = m.user_id
  WHERE t.archetype = 'regular'
  AND t.created_at >= '#{report.start_date}'
  AND t.created_at <= '#{report.end_date}'
  GROUP BY t.user_id
  ),
  post_count AS (
  SELECT p.user_id,
  COUNT(*) AS post_count
  FROM mods m
  JOIN posts p
  ON p.user_id = m.user_id
  JOIN topics t
  ON t.id = p.topic_id
  WHERE t.archetype = 'regular'
  AND p.created_at >= '#{report.start_date}'
  AND p.created_at <= '#{report.end_date}'
  GROUP BY p.user_id
  ),
  pm_count AS (
  SELECT p.user_id,
  COUNT(*) AS pm_count
  FROM mods m
  JOIN posts p
  ON p.user_id = m.user_id
  JOIN topics t
  ON t.id = p.topic_id
  WHERE t.archetype = 'private_message'
  AND p.created_at >= '#{report.start_date}'
  AND p.created_at <= '#{report.end_date}'
  GROUP BY p.user_id
  )

  SELECT
  m.user_id,
  m.username,
  m.uploaded_avatar_id,
  tr.time_read,
  fc.flag_count,
  rc.revision_count,
  tc.topic_count,
  pc.post_count,
  pmc.pm_count
  FROM mods m
  LEFT JOIN time_read tr ON tr.user_id = m.user_id
  LEFT JOIN flag_count fc ON fc.user_id = m.user_id
  LEFT JOIN revision_count rc ON rc.user_id = m.user_id
  LEFT JOIN topic_count tc ON tc.user_id = m.user_id
  LEFT JOIN post_count pc ON pc.user_id = m.user_id
  LEFT JOIN pm_count pmc ON pmc.user_id = m.user_id
  ORDER BY m.username
  SQL

  DB.query(query).each do |row|
    mod = {}
    mod[:username] = row.username
    mod[:user_id] = row.user_id
    mod[:user_avatar_template] = User.avatar_template(row.username, row.uploaded_avatar_id)
    mod[:time_read] = row.time_read
    mod[:flag_count] = row.flag_count
    mod[:revision_count] = row.revision_count
    mod[:topic_count] = row.topic_count
    mod[:post_count] = row.post_count
    mod[:pm_count] = row.pm_count
    report.data << mod
  end
end
