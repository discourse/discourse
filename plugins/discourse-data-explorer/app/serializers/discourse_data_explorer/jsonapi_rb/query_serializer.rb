# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonapiRb
    # jsonapi-serializer equivalent of the Graphiti QueryResource — same wire
    # output (type, attributes, user/groups relationships). id is stringified
    # automatically; datetimes render in TimeWithZone's native format (matching
    # the Graphiti endpoint's scoped-datetime output).
    class QuerySerializer
      include JSONAPI::Serializer
      set_type :queries
      attributes :name, :description, :sql, :last_run_at, :created_at, :updated_at
      # Admin-only field — parity with Graphiti's `attribute :hidden, readable: :admin?`.
      # The guardian is passed in via the serializer's `params` from the controller.
      attribute :hidden, if: proc { |_record, params| params && params[:guardian]&.is_admin? }
      belongs_to :user, serializer: UserSerializer
      has_many :groups, serializer: GroupSerializer
    end
  end
end
