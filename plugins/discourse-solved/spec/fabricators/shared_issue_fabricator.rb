# frozen_string_literal: true
Fabricator(:shared_issue, from: DiscourseSolved::SharedIssue) do
  topic
  user
end
