module HasWebHooks
  extend ActiveSupport::Concern

  included do
    around_destroy :enqueue_web_hook
  end

  def enqueue_web_hook
    type = self.class.name.underscore.to_sym
    payload = WebHook.generate_payload(type, self)
    yield
    WebHook.enqueue_hooks(type, "#{self.class.name.underscore}_destroyed".to_sym,
      id: id,
      payload: payload
    )
  end
end
