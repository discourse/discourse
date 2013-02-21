desc "run phantomjs based smoke tests on current build"
task "smoke:test" => :environment do 
  results = `phantomjs #{Rails.root}/spec/phantom_js/smoke_test.js #{Discourse.base_url}`
  puts results
end
