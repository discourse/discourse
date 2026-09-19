# frozen_string_literal: true

module DiscourseDataExplorer
  class ReportGenerator
    def self.generate(query_id, query_params, recipients, opts = {})
      query = DiscourseDataExplorer::Query.find(query_id)
      return [] if recipients.empty?

      recipients =
        filter_recipients_by_query_access(
          recipients,
          query,
          users_from_group: opts[:users_from_group],
        )
      params = params_to_hash(query_params)
      result = run_query(query, params)

      return [] if opts[:skip_empty] && result[:pg_result].ntuples.zero?
      table =
        ResultToMarkdown.convert(result[:pg_result], render_url_columns: opts[:render_url_columns])

      build_report_pms(query, table, recipients, attach_csv: opts[:attach_csv], result:)
    end

    def self.generate_post(query_id, query_params, opts = {})
      query = DiscourseDataExplorer::Query.find(query_id)
      params = params_to_hash(query_params)
      result = run_query(query, params)

      return {} if opts[:skip_empty] && result[:pg_result].ntuples.zero?
      table =
        ResultToMarkdown.convert(result[:pg_result], render_url_columns: opts[:render_url_columns])

      build_report_post(query, table, attach_csv: opts[:attach_csv], result:)
    end

    def self.run_query(query, params)
      result = DataExplorer.run_query(query, params)
      query.record_run!
      raise result[:error] if result[:error]

      result
    end

    def self.params_to_hash(query_params)
      params = JSON.parse(query_params)

      params.to_h { |p| p.is_a?(Hash) ? [p["key"], p["value"]] : p }
    end

    def self.build_report_pms(query, table = "", targets = [], attach_csv: false, result: nil)
      appendix = upload_appendix(query, result, attach_csv:)

      targets.map do |name, type|
        {
          "title" =>
            I18n.t("data_explorer.report_generator.private_message.title", query_name: query.name),
          "target_#{type}s" => Array(name),
          "raw" =>
            I18n.t(
              "data_explorer.report_generator.private_message.body",
              recipient_name: name,
              query_name: query.name,
              table: table,
              base_url: Discourse.base_url,
              query_id: query.id,
              created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
              timezone: Time.zone.name,
            ) + appendix,
        }
      end
    end

    def self.build_report_post(query, table = "", attach_csv: false, result: nil)
      {
        "raw" =>
          I18n.t(
            "data_explorer.report_generator.post.body",
            query_name: query.name,
            table: table,
            base_url: Discourse.base_url,
            query_id: query.id,
            created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
            timezone: Time.zone.name,
          ) + upload_appendix(query, result, attach_csv:),
      }
    end

    def self.upload_appendix(query, result, attach_csv:)
      return "" unless attach_csv

      upload = create_csv_upload(query, result)
      return "" unless upload.persisted?

      "\n\n" +
        I18n.t(
          "data_explorer.report_generator.upload_appendix",
          filename: upload.original_filename,
          short_url: upload.short_url,
        )
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
      users = User.where(username: recipients).includes(:groups).to_a
      groups = Group.where(name: recipients).to_a
      emails = recipients - users.map(&:username) - groups.map(&:name)

      query_group_ids = [Group::AUTO_GROUPS[:admins]].concat(query.groups.pluck(:group_id)).uniq

      group_targets =
        if users_from_group
          User
            .joins(:group_users)
            .where(group_users: { group_id: groups.map(&:id) })
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
            .map { |username| [username, "username"] }
        else
          groups.filter_map do |group|
            [group.name, "group_name"] if query_group_ids.include?(group.id)
          end
        end

      user_targets =
        users.filter_map do |user|
          [user.username, "username"] if user.guardian.user_can_access_query?(query)
        end

      group_targets + user_targets + emails.filter_map { |e| [e, "email"] if Email.is_valid?(e) }
    end
  end
end
