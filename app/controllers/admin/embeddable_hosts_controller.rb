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
    StaffActionLogger.new(current_user).log_embeddable_host(
      host,
      UserHistory.actions[:embeddable_host_destroy],
    )
    render json: success_json
  end

  protected

  def save_host(host, action)
    host.host = params[:embeddable_host][:host]
    host.allowed_paths = params[:embeddable_host][:allowed_paths]
    host.category_id = params[:embeddable_host][:category_id]
    host.category_id = SiteSetting.uncategorized_category_id if host.category.blank?

    username = params[:embeddable_host][:user]

    if username.blank?
      host.user = nil
    else
      host.user = User.find_by_username(username)
    end

    ActiveRecord::Base.transaction do
      if host.save
        manage_tags(host, params[:embeddable_host][:tags]&.map(&:strip))

        changes = host.saved_changes if action == :update
        StaffActionLogger.new(current_user).log_embeddable_host(
          host,
          UserHistory.actions[:"embeddable_host_#{action}"],
          changes: changes,
        )
        render_serialized(
          host,
          EmbeddableHostSerializer,
          root: "embeddable_host",
          rest_serializer: true,
        )
      else
        render_json_error(host)
        raise ActiveRecord::Rollback
      end
    end
  end

  def manage_tags(host, tags)
    if tags.blank?
      host.tags.clear
      return
    end

    existing_tags = Tag.where(name: tags).index_by(&:name)
    tags_to_associate = []

    tags.each do |tag_name|
      tag = existing_tags[tag_name] || Tag.create(name: tag_name)
      if tag.persisted?
        tags_to_associate << tag
      else
        host.errors.add(:tags, "Failed to create or find tag: #{tag_name}")
        raise ActiveRecord::Rollback
      end
    end

    host.tags = tags_to_associate
  end
end
