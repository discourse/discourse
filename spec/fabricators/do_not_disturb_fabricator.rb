# frozen_string_literal: true

Fabricator(:do_not_disturb_timing) do
  user
  starts_at { Time.zone.now }
  ends_at { 1.hour.from_now }
end
