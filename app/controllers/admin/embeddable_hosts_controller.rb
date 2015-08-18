class Admin::EmbeddableHostsController < Admin::AdminController

  before_filter :ensure_logged_in, :ensure_staff

  def create
    save_host(EmbeddableHost.new)
  end

  def update
    host = EmbeddableHost.where(id: params[:id]).first
    save_host(host)
  end

  def destroy
    host = EmbeddableHost.where(id: params[:id]).first
    host.destroy
    render json: success_json
  end

  protected

    def save_host(host)
      host.host = params[:embeddable_host][:host]
      host.category_id = params[:embeddable_host][:category_id]
      host.category_id = SiteSetting.uncategorized_category_id if host.category_id.blank?

      if host.save
        render_serialized(host, EmbeddableHostSerializer, root: 'embeddable_host', rest_serializer: true)
      else
        render_json_error(host)
      end
    end

end
