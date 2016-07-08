class AdminWebHooksSerializer < ApplicationSerializer
  has_many :web_hooks, serializer: AdminWebHookSerializer, embed: :objects

  attributes :extras,
             :total_rows_web_hooks,
             :load_more_web_hooks,

  def extras
    content_types = WebHook.content_types.map { |name, id| { id: id, name: name } }
    delivery_statuses = WebHook.last_delivery_statuses.map { |name, id| { id: id, name: name.to_s } }

    {
      event_types: ActiveModel::ArraySerializer.new(WebHookEventType.all).as_json,
      default_event_types: ActiveModel::ArraySerializer.new(WebHook.default_event_types).as_json,
      content_types: ActiveModel::ArraySerializer.new(content_types).as_json,
      delivery_statuses: ActiveModel::ArraySerializer.new(delivery_statuses).as_json,
    }
  end

  delegate :total_rows_web_hooks,
           :load_more_web_hooks,
           to: :object
end
