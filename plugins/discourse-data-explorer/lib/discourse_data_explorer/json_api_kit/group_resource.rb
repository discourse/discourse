# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    class GroupResource < ApplicationResource
      type :groups

      attribute :name, :string
    end
  end
end
