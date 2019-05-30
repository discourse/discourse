# frozen_string_literal: true

Report.add_report('top_uploads') do |report|
  report.modes = [:table]

  extension_filter = report.filters.dig(:"file-extension")
  report.add_filter('file-extension',
    default: extension_filter || 'any',
    choices: (
      SiteSetting.authorized_extensions.split('|') + Array(extension_filter)
    ).uniq
  )

  report.labels = [
    {
      type: :link,
      properties: [
        :file_url,
        :file_name,
      ],
      title: I18n.t("reports.top_uploads.labels.filename")
    },
    {
      type: :user,
      properties: {
        username: :author_username,
        id: :author_id,
        avatar: :author_avatar_template,
      },
      title: I18n.t("reports.top_uploads.labels.author")
    },
    {
      type: :text,
      property: :extension,
      title: I18n.t("reports.top_uploads.labels.extension")
    },
    {
      type: :bytes,
      property: :filesize,
      title: I18n.t("reports.top_uploads.labels.filesize")
    },
  ]

  report.data = []

  sql = <<~SQL
  SELECT
  u.id as user_id,
  u.username,
  u.uploaded_avatar_id,
  up.filesize,
  up.original_filename,
  up.extension,
  up.url
  FROM uploads up
  JOIN users u
  ON u.id = up.user_id
  /*where*/
  ORDER BY up.filesize DESC
  LIMIT #{report.limit || 250}
  SQL

  builder = DB.build(sql)
  builder.where("up.id > :seeded_id_threshold", seeded_id_threshold: Upload::SEEDED_ID_THRESHOLD)
  builder.where("up.created_at >= :start_date", start_date: report.start_date)
  builder.where("up.created_at < :end_date", end_date: report.end_date)

  if extension_filter
    builder.where("up.extension = :extension", extension: extension_filter.sub(/^\./, ''))
  end

  builder.query.each do |row|
    data = {}
    data[:author_id] = row.user_id
    data[:author_username] = row.username
    data[:author_avatar_template] = User.avatar_template(row.username, row.uploaded_avatar_id)
    data[:filesize] = row.filesize
    data[:extension] = row.extension
    data[:file_url] = Discourse.store.cdn_url(row.url)
    data[:file_name] = row.original_filename.truncate(25)
    report.data << data
  end
end
