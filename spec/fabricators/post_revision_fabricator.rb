Fabricator(:post_revision) do
  post
  user
  number 2
  modifications do
    { "cooked" => ["<p>BEFORE</p>", "<p>AFTER</p>"], "raw" => ["BEFORE", "AFTER"] }
  end
end
