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
      # lazy_load_data: linkage (and the association load) is emitted only when the
      # relationship is `include`d — matches Graphiti's "no linkage unless included" and
      # closes the flat-request perf gap. The base controller preloads only included
      # relationships and strips the resulting empty relationship objects.
      belongs_to :user, serializer: UserSerializer, lazy_load_data: true
      has_many :groups, serializer: GroupSerializer, lazy_load_data: true
    end
  end
end
