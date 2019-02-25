class Admin::WebHooksController < Admin::AdminController
  before_action :fetch_web_hook, only: %i(show update destroy list_events bulk_events ping)

  def index
    limit = 50
    offset = params[:offset].to_i

    web_hooks = WebHook.limit(limit)
      .offset(offset)
      .includes(:web_hook_event_types)
      .includes(:categories)
      .includes(:groups)

    json = {
      web_hooks: serialize_data(web_hooks, AdminWebHookSerializer),
      extras: {
        event_types: WebHookEventType.all,
        default_event_types: WebHook.default_event_types,
        content_types: WebHook.content_types.map { |name, id| { id: id, name: name } },
        delivery_statuses: WebHook.last_delivery_statuses.map { |name, id| { id: id, name: name.to_s } },
      },
      total_rows_web_hooks: WebHook.count,
      load_more_web_hooks: admin_web_hooks_path(limit: limit, offset: offset + limit, format: :json)
    }

    render json: MultiJson.dump(json), status: 200
  end

  def show
    render_serialized(@web_hook, AdminWebHookSerializer, root: 'web_hook')
  end

  def create
    web_hook = WebHook.new(web_hook_params)

    if web_hook.save
      render_serialized(web_hook, AdminWebHookSerializer, root: 'web_hook')
    else
      render_json_error web_hook.errors.full_messages
    end
  end

  def update
    if @web_hook.update_attributes(web_hook_params)
      render_serialized(@web_hook, AdminWebHookSerializer, root: 'web_hook')
    else
      render_json_error @web_hook.errors.full_messages
    end
  end

  def destroy
    @web_hook.destroy!
    render json: success_json
  end

  def new
  end

  def list_events
    limit = 50
    offset = params[:offset].to_i

    json = {
      web_hook_events: serialize_data(@web_hook.web_hook_events.limit(limit).offset(offset), AdminWebHookEventSerializer),
      total_rows_web_hook_events: @web_hook.web_hook_events.count,
      load_more_web_hook_events: web_hook_events_admin_api_index_path(limit: limit, offset: offset + limit, format: :json),
      extras: {
        web_hook_id: @web_hook.id
      }
    }

    render json: MultiJson.dump(json), status: 200
  end

  def bulk_events
    params.require(:ids)
    web_hook_events = @web_hook.web_hook_events.where(id: params[:ids])
    render_serialized(web_hook_events, AdminWebHookEventSerializer)
  end

  def redeliver_event
    web_hook_event = WebHookEvent.find(params[:event_id])

    if web_hook_event
      web_hook = web_hook_event.web_hook
      conn = Excon.new(URI(web_hook.payload_url).to_s,
                       ssl_verify_peer: web_hook.verify_certificate,
                       retry_limit: 0)

      now = Time.zone.now
      response = conn.post(headers: MultiJson.load(web_hook_event.headers), body: web_hook_event.payload)
      web_hook_event.update_attributes!(status: response.status,
                                        response_headers: MultiJson.dump(response.headers),
                                        response_body: response.body,
                                        duration: ((Time.zone.now - now) * 1000).to_i)
      render_serialized(web_hook_event, AdminWebHookEventSerializer, root: 'web_hook_event')
    else
      render json: failed_json
    end
  end

  def ping
    Jobs.enqueue(:emit_web_hook_event, web_hook_id: @web_hook.id, event_type: 'ping', event_name: 'ping')
    render json: success_json
  end

  private

  def web_hook_params
    params.require(:web_hook).permit(:payload_url, :content_type, :secret,
                                     :wildcard_web_hook, :active, :verify_certificate,
                                     web_hook_event_type_ids: [],
                                     group_ids: [],
                                     tag_names: [],
                                     category_ids: [])
  end

  def fetch_web_hook
    @web_hook = WebHook.find(params[:id])
  end
end
