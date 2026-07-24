# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    class GroupResource < ApplicationResource
      type :groups
      description "A group a query is shared with."

      attribute :name, :string
    end
  end
end
