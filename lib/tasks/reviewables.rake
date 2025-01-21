# frozen_string_literal: true

desc "Perform an action on all pending reviewables of a given type"
task "reviewables:mass-handle", %i[reviewable_type username action_id] => :environment do |_, args|
  args_hash = args.to_hash

  if args_hash.size == 0
    pending_types = Reviewable.where(status: Reviewable.statuses[:pending]).distinct.pluck(:type)
    puts <<~HELP
      rake reviewables:mass-handle[reviewable_type,username,action]
      reviewable_type:
        a type of `Reviewable` such as `ReviewableFlaggedPost`, `ReviewableQueuedPost` etc.
        Your site currently has #{pending_types.size} types with pending records, and they are:
        #{pending_types}
      username:
        username of the acting user who will perform the action on the reviewables
      action:
        the name of the action that you want to mass-perform on pending
        reviewables. There isn't one set of actions that works on all types of
        reviewables because each type defines its own set of actions.
        To list all available actions for a given type, run this rake task
        without the action argument and it will print the list of actions that
        you can perform.
    HELP
    next
  end

  reviewable_class =
    begin
      args[:reviewable_type]&.constantize
    rescue NameError
      raise "#{args[:reviewable_type].inspect} is not a valid Reviewable type."
    end

  if !reviewable_class || !(reviewable_class < Reviewable)
    raise "#{args[:reviewable_type].inspect} is not a Reviewable subclass."
  end

  acting_user = User.find_by(username_lower: args[:username]&.downcase)
  raise "Cannot find user with id=#{args[:username].inspect}." if !acting_user

  relation = reviewable_class.where(status: Reviewable.statuses[:pending])
  count = relation.count

  if count == 0
    puts "There are 0 pending #{reviewable_class}. Nothing to do."
    next
  end

  if !args_hash.key?(:action_id)
    collection = relation.first.actions_for(acting_user.guardian)
    actions = collection.bundles.map(&:actions).flatten.map(&:server_action)

    puts <<~MSG
      You need to specify an action to perform on the #{count} pending #{reviewable_class}.
      Here's a list of the all avaiable actions on the #{reviewable_class} type:
      #{actions.join("\n")}
    MSG
    next
  end

  action_id = args[:action_id]
  if !reviewable_class.method_defined?(:"perform_#{action_id}")
    raise "#{reviewable_class} doesn't support an action with the name #{action_id.inspect}."
  end

  print <<~MSG.strip + " "
    There are #{count} pending #{reviewable_class} records.
    @#{acting_user.username} will perform #{action_id.inspect} on them.
    Are you sure you want to proceed? Type "#{count}" to confirm or "n" to cancel:
  MSG

  while true
    input = STDIN.readline.strip

    if input == "n"
      puts "Task cancelled."
      break
    elsif input == count.to_s
      puts "Performing #{action_id.inspect} on #{count} #{reviewable_class} records..."
      failed = []
      relation.find_each do |reviewable|
        result = reviewable.perform(acting_user, action_id)

        if result.success?
          putc "."
        else
          putc "F"
          failed << { reviewable:, errors: result.errors }
        end
      rescue => error
        putc "F"
        failed << { reviewable:, errors: [error] }
      end

      puts ""
      puts "#{count - failed.size} records have been processed successfully and #{failed.size} failed."

      if failed.size > 0
        puts "Here's a detailed report of each record that failed:"
        failed.each do |obj|
          puts <<~TEXT
            reviewable id: #{obj[:reviewable].id}
            errors: #{obj[:errors].inspect}
          TEXT
          puts "=" * 50
        end
      end
      break
    else
      print "Can't understand your input. Please try again: "
    end
  end
end
