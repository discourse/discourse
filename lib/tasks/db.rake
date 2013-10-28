# we need to run seed_fu every time we run rake db:migrate
task 'db:migrate' => 'environment' do
  SeedFu.seed
end

task 'test:prepare' => 'environment' do
  SeedFu.seed
end
