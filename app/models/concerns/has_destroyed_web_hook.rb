module HasDestroyedWebHook
  extend ActiveSupport::Concern

  included do
    around_destroy :enqueue_destroyed_web_hook
  end

  def enqueue_destroyed_web_hook
    type = self.class.name.underscore.to_sym
    payload = WebHook.generate_payload(type, self)
    yield
    WebHook.enqueue_hooks(type, "#{type}_destroyed".to_sym,
      id: id,
      payload: payload
    )
  end
end
