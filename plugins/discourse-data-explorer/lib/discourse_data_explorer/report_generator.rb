# frozen_string_literal: true

module ::DiscourseDataExplorer
  class ReportGenerator
    def self.generate(query_id, query_params, recipients, opts = {})
      query = DiscourseDataExplorer::Query.find(query_id)
      return [] if !query || recipients.empty?

      recipients =
        filter_recipients_by_query_access(
          recipients,
          query,
          users_from_group: opts[:users_from_group],
        )
      params = params_to_hash(query_params)

      result = DataExplorer.run_query(query, params)
      query.update!(last_run_at: Time.now)

      return [] if opts[:skip_empty] && result[:pg_result].values.empty?
      table =
        ResultToMarkdown.convert(result[:pg_result], render_url_columns: opts[:render_url_columns])

      build_report_pms(query, table, recipients, attach_csv: opts[:attach_csv], result:)
    end

    def self.generate_post(query_id, query_params, opts = {})
      query = DiscourseDataExplorer::Query.find(query_id)
      return {} if !query

      params = params_to_hash(query_params)

      result = DataExplorer.run_query(query, params)
      query.update!(last_run_at: Time.now)

      return {} if opts[:skip_empty] && result[:pg_result].values.empty?
      table =
        ResultToMarkdown.convert(result[:pg_result], render_url_columns: opts[:render_url_columns])

      build_report_post(query, table, attach_csv: opts[:attach_csv], result:)
    end

    def self.params_to_hash(query_params)
      params = JSON.parse(query_params)

      params.map { |p| p.is_a?(Hash) ? [p["key"], p["value"]] : p }.to_h
    end

    def self.build_report_pms(query, table = "", targets = [], attach_csv: false, result: nil)
      pms = []
      upload = create_csv_upload(query, result) if attach_csv

      targets.each do |target|
        name = target[0]
        pm_type = "target_#{target[1]}s"

        pm = {}
        pm["title"] = I18n.t(
          "data_explorer.report_generator.private_message.title",
          query_name: query.name,
        )
        pm[pm_type] = Array(name)
        pm["raw"] = I18n.t(
          "data_explorer.report_generator.private_message.body",
          recipient_name: name,
          query_name: query.name,
          table: table,
          base_url: Discourse.base_url,
          query_id: query.id,
          created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
          timezone: Time.zone.name,
        )
        if upload
          pm["raw"] << "\n\n" +
            I18n.t(
              "data_explorer.report_generator.upload_appendix",
              filename: upload.original_filename,
              short_url: upload.short_url,
            )
        end
        pms << pm
      end
      pms
    end

    def self.build_report_post(query, table = "", attach_csv: false, result: nil)
      upload = create_csv_upload(query, result) if attach_csv

      post = {}
      post["raw"] = I18n.t(
        "data_explorer.report_generator.post.body",
        recipient_name: name,
        query_name: query.name,
        table: table,
        base_url: Discourse.base_url,
        query_id: query.id,
        created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
        timezone: Time.zone.name,
      )

      if upload
        post["raw"] << "\n\n" +
          I18n.t(
            "data_explorer.report_generator.upload_appendix",
            filename: upload.original_filename,
            short_url: upload.short_url,
          )
      end

      post
    end

    def self.create_csv_upload(query, result)
      tmp_filename =
        "#{query.slug}@#{Slug.for(Discourse.current_hostname, "discourse")}-#{Date.today}.dcqresult.csv"
      tmp = Tempfile.new(tmp_filename)
      tmp.write(ResultFormatConverter.convert(:csv, result))
      tmp.rewind
      UploadCreator.new(tmp, tmp_filename, type: "csv_export").create_for(Discourse.system_user.id)
    end

    def self.filter_recipients_by_query_access(recipients, query, users_from_group: false)
      users = User.where(username: recipients)
      groups = Group.where(name: recipients)
      emails = recipients - users.pluck(:username) - groups.pluck(:name)
      result = []

      query_group_ids = [Group::AUTO_GROUPS[:admins]].concat(query.groups.pluck(:group_id)).uniq

      if users_from_group
        result.concat(
          User
            .joins(:group_users)
            .where(group_users: { group_id: groups.ids })
            .where(
              "users.admin OR EXISTS (
                SELECT 1 FROM group_users gu
                WHERE gu.user_id = users.id
                AND gu.group_id IN (?)
              )",
              query_group_ids,
            )
            .distinct
            .pluck(:username)
            .map { |username| [username, "username"] },
        )
      else
        groups.each do |group|
          result << [group.name, "group_name"] if query_group_ids.include?(group.id)
        end
      end

      users.each do |user|
        result << [user.username, "username"] if Guardian.new(user).user_can_access_query?(query)
      end

      emails.each { |email| result << [email, "email"] if Email.is_valid?(email) }

      result
    end
  end
end
