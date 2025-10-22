# frozen_string_literal: true

# rake data_explorer:list_hidden_queries
desc "Shows a list of hidden queries"
task "data_explorer:list_hidden_queries" => :environment do |t|
  puts "\nHidden Queries\n\n"

  hidden_queries = DiscourseDataExplorer::Query.where(hidden: false)

  hidden_queries.each do |query|
    puts "Name: #{query.name}"
    puts "Description: #{query.description}"
    puts "ID: #{query.id}\n\n"
  end
end

# rake data_explorer[-1]
# rake data_explorer[1,-2,3,-4,5]
desc "Hides one or multiple queries by ID"
task "data_explorer" => :environment do |t, args|
  args.extras.each do |arg|
    id = arg.to_i
    query = DiscourseDataExplorer::Query.find_by(id: id)
    if query
      puts "\nFound query with id #{id}"
      query.update!(hidden: true)
      puts "Query no.#{id} is now hidden"
    else
      puts "\nError finding query with id #{id}"
    end
  end
  puts ""
end

# rake data_explorer:unhide_query[-1]
# rake data_explorer:unhide_query[1,-2,3,-4,5]
desc "Unhides one or multiple queries by ID"
task "data_explorer:unhide_query" => :environment do |t, args|
  args.extras.each do |arg|
    id = arg.to_i
    query = DiscourseDataExplorer::Query.find_by(id: id)
    if query
      puts "\nFound query with id #{id}"
      query.update!(hidden: false)
      puts "Query no.#{id} is now visible"
    else
      puts "\nError finding query with id #{id}"
    end
  end
  puts ""
end

# rake data_explorer:hard_delete[-1]
# rake data_explorer:hard_delete[1,-2,3,-4,5]
desc "Hard deletes one or multiple queries by ID"
task "data_explorer:hard_delete" => :environment do |t, args|
  args.extras.each do |arg|
    id = arg.to_i
    query = DiscourseDataExplorer::Query.find_by(id: id)
    if query
      puts "\nFound query with id #{id}"

      if query.hidden
        query.destroy!
        puts "Query no.#{id} has been deleted"
      else
        puts "Query no.#{id} must be hidden in order to hard delete"
        puts "To hide the query, run: " + "rake data_explorer[#{id}]"
      end
    else
      puts "\nError finding query with id #{id}"
    end
  end
  puts ""
end
