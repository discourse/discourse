# frozen_string_literal: true

Fabricator(:do_not_disturb_timing) do
  user
  starts_at { Time.current }
  ends_at { Time.current + 1.hour }
end
