# frozen_string_literal: true

task "chat_messages:rebake_uncooked_chat_messages" => :environment do
  # rebaking uncooked chat_messages can very quickly saturate sidekiq
  # this provides an insurance policy so you can safely run and stop
  # this rake task without worrying about your sidekiq imploding
  Jobs.run_immediately!

  ENV["RAILS_DB"] ? rebake_uncooked_chat_messages : rebake_uncooked_chat_messages_all_sites
end

def rebake_uncooked_chat_messages_all_sites
  RailsMultisite::ConnectionManagement.each_connection { |db| rebake_uncooked_chat_messages }
end

def rebake_uncooked_chat_messages
  puts "Rebaking uncooked chat messages on #{RailsMultisite::ConnectionManagement.current_db}"
  uncooked = Chat::Message.uncooked

  rebaked = 0
  total = uncooked.count

  ids = uncooked.pluck(:id)
  # work randomly so you can run this job from lots of consoles if needed
  ids.shuffle!

  ids.each do |id|
    # may have been cooked in interim
    chat_message = uncooked.where(id: id).first

    rebake_chat_message(chat_message) if chat_message

    print_status(rebaked += 1, total)
  end

  puts "", "#{rebaked} chat messages done!", ""
end

def rebake_chat_message(chat_message, opts = {})
  opts[:priority] = :ultra_low if !opts[:priority]
  chat_message.rebake!(**opts)
rescue => e
  puts "",
       "Failed to rebake chat message (chat_message_id: #{chat_message.id})",
       e,
       e.backtrace.join("\n")
end

task "chat:make_channel_to_test_archiving", [:user_for_membership] => :environment do |t, args|
  user_for_membership = args[:user_for_membership]

  # do not want this running in production!
  return if !Rails.env.development?

  require "fabrication"
  Dir[Rails.root.join("spec/fabricators/*.rb")].each { |f| require f }

  messages = [
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
    "Cras sit **amet** metus eget nisl accumsan ullamcorper.",
    "Vestibulum commodo justo _quis_ fringilla fringilla.",
    "Etiam malesuada erat eget aliquam interdum.",
    "Praesent mattis lacus nec ~~orci~~ [spoiler]semper[/spoiler], et fermentum augue tincidunt.",
    "Duis vel tortor suscipit justo fringilla faucibus id tempus purus.",
    "Phasellus *tempus erat* sit amet pharetra facilisis.",
    "Fusce egestas urna ut nisi ornare, ut malesuada est fermentum.",
    "Aenean ornare arcu vitae pulvinar dictum.",
    "Nam at turpis eu magna sollicitudin fringilla sed sed diam.",
    "Proin non [enim](https://discourse.org/team) nec mauris efficitur convallis.",
    "Nullam cursus lacus non libero vulputate ornare.",
    "In eleifend ante ut ullamcorper ultrices.",
    "In placerat diam sit amet nibh feugiat, in posuere metus feugiat.",
    "Nullam porttitor leo a leo `cursus`, id hendrerit dui ultrices.",
    "Pellentesque ut @#{user_for_membership} ut ex pulvinar pharetra sit amet ac leo.",
    "Vestibulum sit amet enim et lectus tincidunt rhoncus hendrerit in enim.",
    <<~MSG,
      some bigger message

      ```ruby
      beep = \"wow\"
      puts beep
      ```
    MSG
  ]

  topic = nil
  chat_channel = nil

  Topic.transaction do
    topic =
      Fabricate(
        :topic,
        user: make_test_user,
        title: "Testing topic for chat archiving #{SecureRandom.hex(4)}",
      )
    Fabricate(
      :post,
      topic: topic,
      user: topic.user,
      raw: "This is some cool first post for archive stuff",
    )
    chat_channel =
      Chat::Channel.create(
        chatable: topic,
        chatable_type: "Topic",
        name: "testing channel for archiving #{SecureRandom.hex(4)}",
      )
  end

  puts "topic: #{topic.id}, #{topic.title}"
  puts "channel: #{chat_channel.id}, #{chat_channel.name}"

  users = [make_test_user, make_test_user, make_test_user]

  Chat::Channel.transaction do
    start_time = Time.now

    puts "creating 1039 messages for the channel"
    1039.times do
      cm =
        Chat::Message.new(message: messages.sample, user: users.sample, chat_channel: chat_channel)
      cm.cook
      cm.save!
    end

    puts "message creation done"
    puts "took #{Time.now - start_time} seconds"

    Chat::UserChatChannelMembership.create(
      chat_channel: chat_channel,
      last_read_message_id: 0,
      user: User.find_by(username: user_for_membership),
      following: true,
    )
  end

  puts "channel is located at #{chat_channel.url}"
end

def make_test_user
  return if !Rails.env.development?
  unique_prefix = "archiveuser#{SecureRandom.hex(4)}"
  Fabricate(:user, username: unique_prefix, email: "#{unique_prefix}@testemail.com")
end
