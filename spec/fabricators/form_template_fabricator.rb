# frozen_string_literal: true

Fabricator(:form_template) do
  name { sequence(:name) { |i| "template_#{i}" } }
  template "some yaml template: value"
end
