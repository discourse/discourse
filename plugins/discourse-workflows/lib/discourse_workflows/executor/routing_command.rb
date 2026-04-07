# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module RoutingCommand
      StoreContext = Data.define(:name, :items)
      Enqueue = Data.define(:node, :items)
      RecordStep = Data.define(:node_name, :step)
      Pause = Data.define(:node, :step, :error)
    end
  end
end
