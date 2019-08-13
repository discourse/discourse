# frozen_string_literal: true

Report.add_report('post_edits') do |report|
  category_filter = report.filters.dig(:category)
  report.add_filter('category', default: category_filter)

  report.modes = [:table]

  report.labels = [
    {
      type: :date,
      property: :created_at,
      title: I18n.t("reports.post_edits.labels.edited_at")
    },
    {
      type: :post,
      properties: {
        topic_id: :topic_id,
        number: :post_number,
        truncated_raw: :post_raw
      },
      title: I18n.t("reports.post_edits.labels.post")
    },
    {
      type: :user,
      properties: {
        username: :editor_username,
        id: :editor_id,
        avatar: :editor_avatar_template,
      },
      title: I18n.t("reports.post_edits.labels.editor")
    },
    {
      type: :user,
      properties: {
        username: :author_username,
        id: :author_id,
        avatar: :author_avatar_template,
      },
      title: I18n.t("reports.post_edits.labels.author")
    },
    {
      type: :text,
      property: :edit_reason,
      title: I18n.t("reports.post_edits.labels.edit_reason")
    },
  ]

  report.data = []

  builder = DB.build <<~SQL
  SELECT
    pr.user_id AS editor_id,
    editor.username AS editor_username,
    editor.uploaded_avatar_id AS editor_avatar_id,
    p.user_id AS author_id,
    author.username AS author_username,
    author.uploaded_avatar_id AS author_avatar_id,
    pr.number AS revision_version,
    p.version AS post_version,
    pr.post_id,
    LEFT(p.raw, 40) AS post_raw,
    p.topic_id,
    p.post_number,
    p.edit_reason,
    pr.created_at
  FROM post_revisions pr
  JOIN posts p
    ON p.id = pr.post_id
  JOIN users author
    ON author.id = p.user_id
  JOIN users editor
    ON editor.id = pr.user_id
  /*join*/
  /*where*/
  ORDER BY pr.created_at ASC
  /*limit*/
  SQL

  if category_filter
    builder.join "topics t ON t.id = p.topic_id"
    builder.where("t.category_id = :category_id
      OR t.category_id IN (
        SELECT id FROM categories
        WHERE categories.parent_category_id = :category_id
      )", category_id: category_filter)
  end

  builder.where("editor.id > 0 AND editor.id != author.id")
  builder.where("pr.created_at >= :start_date", start_date: report.start_date)
  builder.where("pr.created_at <= :end_date", end_date: report.end_date)

  result = builder.query

  result.each do |r|
    revision = {}
    revision[:editor_id] = r.editor_id
    revision[:editor_username] = r.editor_username
    revision[:editor_avatar_template] = User.avatar_template(r.editor_username, r.editor_avatar_id)
    revision[:author_id] = r.author_id
    revision[:author_username] = r.author_username
    revision[:author_avatar_template] = User.avatar_template(r.author_username, r.author_avatar_id)
    revision[:edit_reason] = r.revision_version == r.post_version ? r.edit_reason : nil
    revision[:created_at] = r.created_at
    revision[:post_raw] = r.post_raw
    revision[:topic_id] = r.topic_id
    revision[:post_number] = r.post_number

    report.data << revision
  end
end
