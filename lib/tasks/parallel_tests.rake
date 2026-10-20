# frozen_string_literal: true

if Rails.env.local?
  require "parallel_tests"
  require "parallel_tests/tasks"

  namespace :parallel do
    desc "Clone the test database for parallel test processes"
    task :clone, [:count] => :environment do |_, args|
      number_of_processes = ParallelTests.determine_number_of_processes(args[:count])
      database = ActiveRecord::Base.connection_db_config.database

      ActiveRecord::Base.remove_connection

      Parallel.each(1..number_of_processes, in_processes: 4) do |process_number|
        system(
          "createdb",
          "--maintenance-db=postgres",
          "--template=#{database}",
          "#{database}_#{process_number}",
          exception: true,
        )
      end
    end
  end
end
