# frozen_string_literal: true

module Sidebar
  class TagSerializer < ::ApplicationSerializer
    attributes :name, :pm_only

    def pm_only
      object.topic_count == 0 && object.pm_topic_count > 0
    end
  end
end
