desc "migrate all sites in tier"
task "multisite:migrate" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Migrating #{db}"
    puts "---------------------------------\n"
    t = Rake::Task["db:migrate"]
    t.reenable
    t.invoke
  end
end

task "multisite:seed_fu" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Seeding #{db}"
    puts "---------------------------------\n"
    t = Rake::Task["db:seed_fu"]
    t.reenable
    t.invoke
  end
end

desc "rollback migrations for all sites in tier"
task "multisite:rollback" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Rollback #{db}"
    puts "---------------------------------\n"
    t = Rake::Task["db:rollback"]
    t.reenable
    t.invoke
  end
end
