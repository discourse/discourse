# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UnlockPost
      class V1 < NodeType
        include PostLockAction

        LOCKED = false

        description(PostLockAction.description(name: "action:unlock_post", icon: "unlock"))
      end
    end
  end
end
