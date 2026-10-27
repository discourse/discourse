# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module LockPost
      class V1 < NodeType
        include PostLockAction

        LOCKED = true

        description(PostLockAction.description(name: "action:lock_post", icon: "lock"))
      end
    end
  end
end
