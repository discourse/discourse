# frozen_string_literal: true

Report.add_report("flags_status") do |report|
  report.modes = [:table]

  report.labels = [
    {
      type: :post,
      properties: {
        topic_id: :topic_id,
        number: :post_number,
        truncated_raw: :post_type
      },
      title: I18n.t("reports.flags_status.labels.flag")
    },
    {
      type: :user,
      properties: {
        username: :staff_username,
        id: :staff_id,
        avatar: :staff_avatar_template
      },
      title: I18n.t("reports.flags_status.labels.assigned")
    },
    {
      type: :user,
      properties: {
        username: :poster_username,
        id: :poster_id,
        avatar: :poster_avatar_template
      },
      title: I18n.t("reports.flags_status.labels.poster")
    },
    {
      type: :user,
      properties: {
        username: :flagger_username,
        id: :flagger_id,
        avatar: :flagger_avatar_template
        },
      title: I18n.t("reports.flags_status.labels.flagger")
    },
    {
      type: :seconds,
      property: :response_time,
      title: I18n.t("reports.flags_status.labels.time_to_resolution")
    }
  ]

  report.data = []

  flag_types = PostActionType.flag_types

  sql = <<~SQL
  WITH period_actions AS (
  SELECT id,
  post_action_type_id,
  created_at,
  agreed_at,
  disagreed_at,
  deferred_at,
  agreed_by_id,
  disagreed_by_id,
  deferred_by_id,
  post_id,
  user_id,
  COALESCE(disagreed_at, agreed_at, deferred_at) AS responded_at
  FROM post_actions
  WHERE post_action_type_id IN (#{flag_types.values.join(',')})
    AND created_at >= '#{report.start_date}'
    AND created_at <= '#{report.end_date}'
  ORDER BY created_at DESC
  ),
  poster_data AS (
  SELECT pa.id,
  p.user_id AS poster_id,
  p.topic_id as topic_id,
  p.post_number as post_number,
  u.username_lower AS poster_username,
  u.uploaded_avatar_id AS poster_avatar_id
  FROM period_actions pa
  JOIN posts p
  ON p.id = pa.post_id
  JOIN users u
  ON u.id = p.user_id
  ),
  flagger_data AS (
  SELECT pa.id,
  u.id AS flagger_id,
  u.username_lower AS flagger_username,
  u.uploaded_avatar_id AS flagger_avatar_id
  FROM period_actions pa
  JOIN users u
  ON u.id = pa.user_id
  ),
  staff_data AS (
  SELECT pa.id,
  u.id AS staff_id,
  u.username_lower AS staff_username,
  u.uploaded_avatar_id AS staff_avatar_id
  FROM period_actions pa
  JOIN users u
  ON u.id = COALESCE(pa.agreed_by_id, pa.disagreed_by_id, pa.deferred_by_id)
  )
  SELECT
  sd.staff_username,
  sd.staff_id,
  sd.staff_avatar_id,
  pd.poster_username,
  pd.poster_id,
  pd.poster_avatar_id,
  pd.post_number,
  pd.topic_id,
  fd.flagger_username,
  fd.flagger_id,
  fd.flagger_avatar_id,
  pa.post_action_type_id,
  pa.created_at,
  pa.agreed_at,
  pa.disagreed_at,
  pa.deferred_at,
  pa.agreed_by_id,
  pa.disagreed_by_id,
  pa.deferred_by_id,
  COALESCE(pa.disagreed_at, pa.agreed_at, pa.deferred_at) AS responded_at
  FROM period_actions pa
  FULL OUTER JOIN staff_data sd
  ON sd.id = pa.id
  FULL OUTER JOIN flagger_data fd
  ON fd.id = pa.id
  FULL OUTER JOIN poster_data pd
  ON pd.id = pa.id
  SQL

  DB.query(sql).each do |row|
    data = {}

    data[:post_type] = flag_types.key(row.post_action_type_id).to_s
    data[:post_number] = row.post_number
    data[:topic_id] = row.topic_id

    if row.staff_id
      data[:staff_username] = row.staff_username
      data[:staff_id] = row.staff_id
      data[:staff_avatar_template] = User.avatar_template(row.staff_username, row.staff_avatar_id)
    end

    if row.poster_id
      data[:poster_username] = row.poster_username
      data[:poster_id] = row.poster_id
      data[:poster_avatar_template] = User.avatar_template(row.poster_username, row.poster_avatar_id)
    end

    if row.flagger_id
      data[:flagger_id] = row.flagger_id
      data[:flagger_username] = row.flagger_username
      data[:flagger_avatar_template] = User.avatar_template(row.flagger_username, row.flagger_avatar_id)
    end

    if row.agreed_by_id
      data[:resolution] = I18n.t("reports.flags_status.values.agreed")
    elsif row.disagreed_by_id
      data[:resolution] = I18n.t("reports.flags_status.values.disagreed")
    elsif row.deferred_by_id
      data[:resolution] = I18n.t("reports.flags_status.values.deferred")
    else
      data[:resolution] = I18n.t("reports.flags_status.values.no_action")
    end
    data[:response_time] = row.responded_at ? row.responded_at - row.created_at : nil
    report.data << data
  end
end
