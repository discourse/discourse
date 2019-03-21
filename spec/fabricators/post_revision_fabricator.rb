Fabricator(:post_revision) do
  post
  user
  number 2
  modifications do
    { 'cooked' => %w[<p>BEFORE</p> <p>AFTER</p>], 'raw' => %w[BEFORE AFTER] }
  end
end
