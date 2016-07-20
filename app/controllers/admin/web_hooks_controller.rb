class Admin::WebHooksController < Admin::AdminController
  before_filter :fetch_web_hook, only: %i(show update destroy)

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
      load_more_web_hooks: Discourse.base_url + admin_web_hooks_path(limit: limit, offset: offset + limit, format: :json)
    }

    render json: MultiJson.dump(json), status: 200
  end

  def show
    render_serialized(@webhook, AdminWebHookSerializer, root: 'web_hook')
  end

  def create
    webhook = WebHook.new(webhook_params)

    if webhook.save
      render_serialized(webhook, AdminWebHookSerializer, root: 'web_hook')
    else
      render_json_error webhook.errors.full_messages
    end
  end

  def update
    if @webhook.update_attributes(webhook_params)
      render_serialized(@webhook, AdminWebHookSerializer, root: 'web_hook')
    else
      render_json_error @webhook.errors.full_messages
    end
  end

  def destroy
    @webhook.destroy!
    render json: success_json
  end

  def new
  end

  private

  def webhook_params
    params.require(:web_hook).permit(:payload_url, :content_type, :secret,
                                     :wildcard_web_hook, :active, :verify_certificate,
                                     web_hook_event_type_ids: [],
                                     group_ids: [],
                                     category_ids: [])
  end

  def fetch_web_hook
    @webhook = WebHook.find(params[:id])
  end
end
