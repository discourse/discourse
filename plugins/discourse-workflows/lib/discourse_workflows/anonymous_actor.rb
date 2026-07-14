# frozen_string_literal: true

module DiscourseWorkflows
  # Special "Performed by" actor that runs a node operation as a logged-out
  # visitor. It is selected in the editor through the actor control and stored
  # as the reserved username +USERNAME+.
  class AnonymousActor < Guardian::AnonymousUser
    USERNAME = "anonymous"

    def id
      nil
    end

    def username
      USERNAME
    end

    def guardian
      @guardian ||= Guardian.new
    end
  end
end
