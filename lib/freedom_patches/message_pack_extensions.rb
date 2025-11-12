# frozen_string_literal: true

# Patch from https://github.com/rails/rails/pull/54584.
# TODO: Drop this once Rails 8.1 is released.

require "active_support/message_pack"
require "active_support/core_ext/string/output_safety"

module MessagePackExtensions
  def install(registry)
    super
    registry.register_type 18, ActiveSupport::SafeBuffer, packer: :to_s, unpacker: :new
  end
end

ActiveSupport::MessagePack::Extensions.prepend(MessagePackExtensions)
