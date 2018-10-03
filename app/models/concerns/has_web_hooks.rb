module HasWebHooks
  extend ActiveSupport::Concern

  included do
    def around_destroy
      type = self.class.name.underscore.to_sym
      payload = WebHook.generate_payload(type, self)
      yield
      WebHook.enqueue_hooks(type, "#{self.class.name.underscore}_destroyed".to_sym,
        id: id,
        payload: payload
      )
    end
  end
end
