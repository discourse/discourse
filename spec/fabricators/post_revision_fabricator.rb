# frozen_string_literal: true

Fabricator(:post_revision) do
  post
  user
  number 2
  modifications { { "cooked" => %w[<p>BEFORE</p> <p>AFTER</p>], "raw" => %w[BEFORE AFTER] } }
end
