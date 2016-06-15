class Admin::WebHooksController < Admin::AdminController
  before_filter :fetch_web_hook, only: %i(show update destroy)

  def index
    # TODO: Pagination
    data = {
      web_hooks: WebHook.all.to_a
    }
    render_serialized(OpenStruct.new(data), AdminWebHooksSerializer, root: false)
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
