# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # The Query resource: type, attributes, and user/groups relationships. id is
    # stringified automatically; datetimes render in TimeWithZone's native format.
    class QuerySerializer
      include JSONAPI::Serializer
      set_type :queries
      attributes :name, :description, :sql, :last_run_at, :created_at, :updated_at
      # Admin-only field. The guardian is passed in via the serializer's `params`
      # from the controller.
      attribute :hidden, if: proc { |_record, params| params && params[:guardian]&.is_admin? }
      # lazy_load_data: linkage (and the association load) is emitted only when the
      # relationship is `include`d — no linkage unless included, which closes the
      # flat-request perf gap. The base controller preloads only included
      # relationships and strips the resulting empty relationship objects.
      belongs_to :user, serializer: UserSerializer, lazy_load_data: true
      has_many :groups, serializer: GroupSerializer, lazy_load_data: true
    end
  end
end
