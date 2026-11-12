# frozen_string_literal: true

module DiscourseSolved::UserExtension
  extend ActiveSupport::Concern

  prepended do
    has_many :discourse_solved_shared_issues,
             class_name: "DiscourseSolved::SharedIssue",
             dependent: :delete_all
  end
end
