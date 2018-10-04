module HasWebHooks
  extend ActiveSupport::Concern

  included do
    around_destroy :enqueue_web_hook
  end

  def enqueue_web_hook
    type = self.class.name.underscore.to_sym
    payload = WebHook.generate_payload(type, self)
    opts = { id: id, payload: payload }
    opts[:category_id] = self.topic&.category_id if type == :post
    yield
    WebHook.enqueue_hooks(type, "#{type}_destroyed".to_sym, opts)
  end
end
