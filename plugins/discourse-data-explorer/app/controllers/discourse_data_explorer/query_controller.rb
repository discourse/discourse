# frozen_string_literal: true

module ::DiscourseDataExplorer
  class QueryController < ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :set_group, only: %i[group_reports_index group_reports_show group_reports_run]
    before_action :set_query, only: %i[group_reports_show group_reports_run show update]
    before_action :ensure_admin

    skip_before_action :check_xhr, only: %i[show group_reports_run run]
    skip_before_action :ensure_admin,
                       only: %i[group_reports_index group_reports_show group_reports_run]

    def index
      queries = Query.where(hidden: false).order(:last_run_at, :name).includes(:groups).to_a

      database_queries_ids = Query.pluck(:id)
      Queries.default.each do |params|
        attributes = params.last
        next if database_queries_ids.include?(attributes["id"])
        query = Query.new
        query.id = attributes["id"]
        query.sql = attributes["sql"]
        query.name = attributes["name"]
        query.description = attributes["description"]
        query.user_id = Discourse::SYSTEM_USER_ID.to_s
        queries << query
      end

      render_serialized queries, QuerySerializer, root: "queries"
    end

    def show
      check_xhr unless params[:export]

      if params[:export]
        response.headers["Content-Disposition"] = "attachment; filename=#{@query.slug}.dcquery.json"
        response.sending_file = true
      end

      return raise Discourse::NotFound if !guardian.user_can_access_query?(@query) || @query.hidden
      render_serialized @query, QueryDetailsSerializer, root: "query"
    end

    def groups
      render json: Group.all.select(:id, :name).as_json(only: %i[id name]), root: false
    end

    def group_reports_index
      return raise Discourse::NotFound unless guardian.user_is_a_member_of_group?(@group)

      respond_to do |format|
        format.json do
          queries = Query.for_group(@group)
          render_serialized(queries, QuerySerializer, root: "queries")
        end
      end
    end

    def group_reports_show
      if !guardian.group_and_user_can_access_query?(@group, @query) || @query.hidden
        return raise Discourse::NotFound
      end

      respond_to do |format|
        format.json do
          query_group = QueryGroup.find_by(query_id: @query.id, group_id: @group.id)

          render json: {
                   query: serialize_data(@query, QueryDetailsSerializer, root: nil),
                   query_group: serialize_data(query_group, QueryGroupSerializer, root: nil),
                 }
        end
      end
    end

    def group_reports_run
      if !guardian.group_and_user_can_access_query?(@group, @query) || @query.hidden
        return raise Discourse::NotFound
      end

      run
    end

    def create
      query =
        Query.create!(
          params
            .require(:query)
            .permit(:name, :description, :sql)
            .merge(user_id: current_user.id, last_run_at: Time.now),
        )
      group_ids = params.require(:query)[:group_ids]
      group_ids&.each { |group_id| query.query_groups.find_or_create_by!(group_id: group_id) }
      render_serialized query, QueryDetailsSerializer, root: "query"
    end

    def update
      ActiveRecord::Base.transaction do
        @query.update!(
          params.require(:query).permit(:name, :sql, :description).merge(hidden: false),
        )

        group_ids = params.require(:query)[:group_ids]
        QueryGroup.where.not(group_id: group_ids).where(query_id: @query.id).delete_all
        group_ids&.each { |group_id| @query.query_groups.find_or_create_by!(group_id: group_id) }
      end

      render_serialized @query, QueryDetailsSerializer, root: "query"
    rescue ValidationError => e
      render_json_error e.message
    end

    def destroy
      query = Query.where(id: params[:id]).first_or_initialize
      query.update!(hidden: true)

      render json: { success: true, errors: [] }
    end

    def schema
      schema_version = DB.query_single("SELECT max(version) AS tag FROM schema_migrations").first
      if stale?(public: true, etag: schema_version, template: false)
        render json: DataExplorer.schema
      end
    end

    # Return value:
    # success - true/false. if false, inspect the errors value.
    # errors - array of strings.
    # params - hash. Echo of the query parameters as executed.
    # duration - float. Time to execute the query, in milliseconds, to 1 decimal place.
    # columns - array of strings. Titles of the returned columns, in order.
    # explain - string. (Optional - pass explain=true in the request) Postgres query plan, UNIX newlines.
    # rows - array of array of strings. Results of the query. In the same order as 'columns'.
    def run
      rate_limit_query_runs!

      check_xhr unless params[:download]

      query = Query.find(params[:id].to_i)
      query.update!(last_run_at: Time.now)

      response.sending_file = true if params[:download]

      query_params = {}
      query_params = MultiJson.load(params[:params]) if params[:params]

      opts = { current_user: current_user&.username }
      opts[:explain] = true if params[:explain] == "true"

      opts[:limit] = if params[:format] == "csv"
        if params[:limit].present?
          limit = params[:limit].to_i
          limit = QUERY_RESULT_MAX_LIMIT if limit > QUERY_RESULT_MAX_LIMIT
          limit
        else
          QUERY_RESULT_MAX_LIMIT
        end
      elsif params[:limit].present?
        params[:limit] == "ALL" ? "ALL" : params[:limit].to_i
      end

      result = DataExplorer.run_query(query, query_params, opts)

      if result[:error]
        err = result[:error]

        # Pretty printing logic
        err_class = err.class
        err_msg = err.message
        if err.is_a? ActiveRecord::StatementInvalid
          err_class = err.original_exception.class
          err_msg.gsub!("#{err_class}:", "")
        else
          err_msg = "#{err_class}: #{err_msg}"
        end

        render json: { success: false, errors: [err_msg] }, status: 422
      else
        content_disposition =
          "attachment; filename=#{query.slug}@#{Slug.for(Discourse.current_hostname, "discourse")}-#{Date.today}.dcqresult"

        respond_to do |format|
          format.json do
            response.headers["Content-Disposition"] = "#{content_disposition}.json" if params[
              :download
            ]

            render json:
                     ResultFormatConverter.convert(
                       :json,
                       result,
                       query_params:,
                       download: params[:download],
                       explain: params[:explain] == "true",
                     )
          end
          format.csv do
            response.headers["Content-Disposition"] = "#{content_disposition}.csv"

            render plain: ResultFormatConverter.convert(:csv, result)
          end
        end
      end
    end

    private

    def rate_limit_query_runs!
      return if !is_api? && !is_user_api?

      RateLimiter.new(
        nil,
        "api-query-run-10-sec",
        GlobalSetting.max_data_explorer_api_reqs_per_10_seconds,
        10.seconds,
      ).performed!
    rescue RateLimiter::LimitExceeded => e
      if GlobalSetting.max_data_explorer_api_req_mode.include?("warn")
        Discourse.warn("Query run 10 second rate limit exceeded", query_id: params[:id])
      end
      raise e if GlobalSetting.max_data_explorer_api_req_mode.include?("block")
    end

    def set_group
      @group = Group.find_by(name: params["group_name"])
    end

    def set_query
      @query = Query.find(params[:id])
      raise Discourse::NotFound unless @query
    end
  end
end
