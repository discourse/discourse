# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryController < ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :set_group, only: %i[group_reports_index group_reports_show group_reports_run]
    before_action :set_query, only: %i[group_reports_show group_reports_run show update public_run]
    before_action :ensure_admin

    skip_before_action :check_xhr, only: %i[show group_reports_run run public_run]
    skip_before_action :ensure_admin,
                       only: %i[group_reports_index group_reports_show group_reports_run public_run]

    INDEX_LIMIT = 50

    SORTABLE_COLUMNS = %w[name username last_run_at].freeze

    def index
      limit = INDEX_LIMIT
      offset = params[:offset].to_i
      filter = params[:filter]

      order_column = SORTABLE_COLUMNS.include?(params[:order]) ? params[:order] : "last_run_at"
      order_direction = params[:ascending] == "true" ? :asc : :desc

      base_scope = DiscourseDataExplorer::Query.where(hidden: false).includes(:groups)

      if order_column == "username"
        base_scope =
          base_scope.joins("LEFT JOIN users ON users.id = data_explorer_queries.user_id").order(
            Arel.sql("users.username #{order_direction}"),
          )
      else
        base_scope = base_scope.order(order_column => order_direction)
      end

      if filter.present?
        sanitized_filter = "%#{Query.sanitize_sql_like(filter)}%"
        base_scope =
          base_scope.where(
            "data_explorer_queries.name ILIKE :filter OR data_explorer_queries.description ILIKE :filter",
            filter: sanitized_filter,
          )
      end

      persisted_count = base_scope.count

      # Default queries are only persisted once run. Build in-memory records
      # for any that haven't been run yet so they still appear in the list.
      persisted_default_ids =
        DiscourseDataExplorer::Query.where(hidden: false).where("id < 0").pluck(:id).to_set
      unpersisted_defaults =
        DiscourseDataExplorer::Queries.default.filter_map do |_, attributes|
          next if persisted_default_ids.include?(attributes["id"])
          if filter.present?
            name_match = attributes["name"]&.downcase&.include?(filter.downcase)
            desc_match = attributes["description"]&.downcase&.include?(filter.downcase)
            next unless name_match || desc_match
          end
          query =
            DiscourseDataExplorer::Query.new(attributes.slice("id", "sql", "name", "description"))
          query.user_id = Discourse::SYSTEM_USER_ID.to_s
          query
        end

      total_rows = persisted_count + unpersisted_defaults.size

      # On the first page, fit defaults within the limit so the page size
      # stays consistent. On subsequent pages, only DB results are returned.
      if offset == 0
        db_limit = [limit - unpersisted_defaults.size, 0].max
        paginated = base_scope.limit(db_limit).to_a
        queries = paginated + unpersisted_defaults
        next_offset = paginated.size
      else
        paginated = base_scope.offset(offset).limit(limit).to_a
        queries = paginated
        next_offset = offset + limit
      end

      json = serialize_data(queries, QuerySerializer, root: "queries")
      json["total_rows_queries"] = total_rows

      if next_offset < persisted_count
        load_more_params = { offset: next_offset }
        load_more_params[:filter] = filter if filter.present?
        load_more_params[:order] = order_column if order_column != "last_run_at"
        load_more_params[:ascending] = "true" if order_direction == :asc
        base_path = request.path.delete_suffix(".json")
        json["load_more_queries"] = "#{base_path}.json?#{load_more_params.to_query}"
      end

      render_json_dump(json)
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

    # Public GET endpoint to run a query by ID for users with access
    def public_run
      return raise Discourse::NotFound if !guardian.user_can_access_query?(@query) || @query.hidden

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
      query = Query.find(params[:id])
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
      if params[:params]
        query_params =
          params[:params].is_a?(String) ? MultiJson.load(params[:params]) : params[:params]
      end

      opts = { current_user: current_user }
      opts[:explain] = true if params[:explain] == "true"

      opts[:limit] = if params[:format] == "csv"
        limit = params.fetch(:limit, QUERY_RESULT_MAX_LIMIT).to_i
        limit = QUERY_RESULT_MAX_LIMIT if limit > QUERY_RESULT_MAX_LIMIT
        limit
      else
        fetch_limit_from_params(
          default: SiteSetting.data_explorer_query_result_limit,
          max: QUERY_RESULT_MAX_LIMIT,
        )
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

        render json: { success: false, errors: [err_msg] }, status: :unprocessable_entity
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
