# frozen_string_literal: true
Fabricator(:me_too, from: DiscourseSolved::MeToo) do
  topic
  user
end
