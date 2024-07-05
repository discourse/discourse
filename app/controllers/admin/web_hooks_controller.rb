# frozen_string_literal: true

class Admin::WebHooksController < Admin::AdminController
  before_action :fetch_web_hook, only: %i[show update destroy list_events bulk_events ping]

  def index
    limit = 50
    offset = params[:offset].to_i

    web_hooks =
      WebHook
        .limit(limit)
        .offset(offset)
        .includes(:web_hook_event_types)
        .includes(:categories)
        .includes(:groups)

    data = serialize_data(web_hooks, AdminWebHookSerializer, root: "web_hooks")

    serialized_grouped_event_types =
      WebHookEventType.active_grouped.transform_values do |array|
        serialize_data(array, WebHookEventTypeSerializer)
      end

    json = {
      web_hooks: data.delete("web_hooks"),
      extras:
        data.merge(
          grouped_event_types: serialized_grouped_event_types,
          default_event_types:
            serialize_data(WebHook.default_event_types, WebHookEventTypeSerializer),
          content_types: WebHook.content_types.map { |name, id| { id: id, name: name } },
          delivery_statuses:
            WebHook.last_delivery_statuses.map { |name, id| { id: id, name: name.to_s } },
        ),
      total_rows_web_hooks: WebHook.count,
      load_more_web_hooks:
        admin_web_hooks_path(limit: limit, offset: offset + limit, format: :json),
    }

    render json: MultiJson.dump(json), status: 200
  end

  def show
    data = serialize_data(@web_hook, AdminWebHookSerializer, root: "web_hook")
    web_hook = data.delete("web_hook")
    data = { "extras" => data, "web_hook" => web_hook }
    render json: MultiJson.dump(data), status: 200
  end

  def edit
    data = serialize_data(@web_hook, AdminWebHookSerializer, root: "web_hook")
    data["extras"] = { "categories" => data.delete(:categories) }
    render json: MultiJson.dump(data), status: 200
  end

  def create
    web_hook = WebHook.new(web_hook_params)

    if web_hook.save
      StaffActionLogger.new(current_user).log_web_hook(
        web_hook,
        UserHistory.actions[:web_hook_create],
      )
      render_serialized(web_hook, AdminWebHookSerializer, root: "web_hook")
    else
      render_json_error web_hook.errors.full_messages
    end
  end

  def update
    if @web_hook.update(web_hook_params)
      StaffActionLogger.new(current_user).log_web_hook(
        @web_hook,
        UserHistory.actions[:web_hook_update],
        changes: @web_hook.saved_changes,
      )
      render_serialized(@web_hook, AdminWebHookSerializer, root: "web_hook")
    else
      render_json_error @web_hook.errors.full_messages
    end
  end

  def destroy
    @web_hook.destroy!
    StaffActionLogger.new(current_user).log_web_hook(
      @web_hook,
      UserHistory.actions[:web_hook_destroy],
    )
    render json: success_json
  end

  def list_events
    limit = 50
    offset = params[:offset].to_i
    events = @web_hook.web_hook_events
    status = params[:status]
    if status == "successful"
      events = events.successful
    elsif status == "failed"
      events = events.failed
    end

    total = events.count
    events = events.limit(limit).offset(offset)

    json = {
      web_hook_events: serialize_data(events, AdminWebHookEventSerializer),
      total_rows_web_hook_events: total,
      load_more_web_hook_events:
        web_hook_events_admin_api_index_path(
          limit: limit,
          offset: offset + limit,
          status: status,
          format: :json,
        ),
      extras: {
        web_hook_id: @web_hook.id,
      },
    }

    render json: MultiJson.dump(json), status: 200
  end

  def bulk_events
    params.require(:ids)
    web_hook_events = @web_hook.web_hook_events.where(id: params[:ids])
    render_serialized(web_hook_events, AdminWebHookEventSerializer)
  end

  def redeliver_event
    web_hook_event = WebHookEvent.find_by(id: params[:event_id])

    if web_hook_event
      web_hook = web_hook_event.web_hook
      emitter = WebHookEmitter.new(web_hook, web_hook_event)
      emitter.emit!(headers: MultiJson.load(web_hook_event.headers), body: web_hook_event.payload)
      render_serialized(web_hook_event, AdminWebHookEventSerializer, root: "web_hook_event")
    else
      render json: failed_json
    end
  end

  def ping
    Jobs.enqueue(
      :emit_web_hook_event,
      web_hook_id: @web_hook.id,
      event_type: "ping",
      event_name: "ping",
    )
    render json: success_json
  end

  private

  def web_hook_params
    params.require(:web_hook).permit(
      :payload_url,
      :content_type,
      :secret,
      :wildcard_web_hook,
      :active,
      :verify_certificate,
      web_hook_event_type_ids: [],
      group_ids: [],
      tag_names: [],
      category_ids: [],
    )
  end

  def fetch_web_hook
    @web_hook = WebHook.find(params[:id])
  end
end
