# frozen_string_literal: true

desc "Print debug information about post_revisions which cannot be deserialized"
task "revisions:debug_deserialization" => :environment do
  puts "Checking #{PostRevision.count} PostRevision records in batches of 1000... this may take some time..."
  sleep 1

  counts = Hash.new(0)
  examples = Hash.new()

  PostRevision.find_each do |revision|
    revision.modifications
  rescue Psych::DisallowedClass => e
    class_name = e.message.sub("Tried to load unspecified class: ", "")
    counts[class_name] += 1
    examples[class_name] ||= revision
    puts "#{Discourse.base_url}/p/#{revision.post_id} (revision number:#{revision.number} id:#{revision.id}) #{e.message}"
  end

  puts
  puts "Done"
  puts

  puts "---- Summary ----"
  puts "Checked records: #{PostRevision.count}"
  counts.each_pair { |k, v| puts "  #{k}: #{v}" }

  puts
  puts "---- Examples ----"
  puts
  examples.each_pair do |class_name, revision|
    puts "-- BEGIN Example #{class_name} --"
    puts
    puts revision.modifications_before_type_cast
    puts
    puts "-- END Example #{class_name} --"
  end
end
