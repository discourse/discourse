# frozen_string_literal: true
class NativeBrowserPage
  attr_reader :target,
              :session,
              :context_id,
              :callbacks,
              :execution_contexts,
              :default_contexts,
              :init_scripts
  attr_accessor :url,
                :viewport,
                :clock,
                :routes,
                :timezone_overridden,
                :network_listener_enabled,
                :navigation_pending,
                :input_navigation_pending,
                :main_frame_id,
                :main_loader,
                :loaded_loader

  def initialize(target:, session:, viewport:, context_id: nil)
    @target = target
    @session = session
    @context_id = context_id
    @viewport = viewport
    @callbacks = Hash.new { |hash, key| hash[key] = [] }
    @execution_contexts = Set.new
    @default_contexts = {}
    @init_scripts = []
    @navigation_pending = false
  end
end
