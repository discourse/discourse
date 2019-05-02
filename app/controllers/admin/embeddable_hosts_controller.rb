# frozen_string_literal: true

class Admin::EmbeddableHostsController < Admin::AdminController

  def create
    save_host(EmbeddableHost.new, :create)
  end

  def update
    host = EmbeddableHost.where(id: params[:id]).first
    save_host(host, :update)
  end

  def destroy
    host = EmbeddableHost.where(id: params[:id]).first
    host.destroy
    StaffActionLogger.new(current_user).log_embeddable_host(host, UserHistory.actions[:embeddable_host_destroy])
    render json: success_json
  end

  protected

  def save_host(host, action)
    host.host = params[:embeddable_host][:host]
    host.path_whitelist = params[:embeddable_host][:path_whitelist]
    host.class_name =  params[:embeddable_host][:class_name]
    host.category_id = params[:embeddable_host][:category_id]
    host.category_id = SiteSetting.uncategorized_category_id if host.category_id.blank?

    if host.save
      changes = host.saved_changes if action == :update
      StaffActionLogger.new(current_user).log_embeddable_host(host, UserHistory.actions[:"embeddable_host_#{action}"], changes: changes)
      render_serialized(host, EmbeddableHostSerializer, root: 'embeddable_host', rest_serializer: true)
    else
      render_json_error(host)
    end
  end

end
