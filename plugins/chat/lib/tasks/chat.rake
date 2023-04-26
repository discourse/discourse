# frozen_string_literal: true

if Discourse.allow_dev_populate?
  desc "Generates sample messages in channels"
  task "chat:message:populate", %i[channel_id count] => ["db:load_config"] do |_, args|
    DiscourseDev::Message.populate!(
      ignore_current_count: true,
      channel_id: args[:channel_id],
      count: args[:count],
    )
  end

  desc "Generates random channels from categories"
  task "chat:category_channel:populate" => ["db:load_config"] do |_, args|
    DiscourseDev::CategoryChannel.populate!(ignore_current_count: true)
  end

  desc "Creates a thread with sample messages in a channel"
  task "chat:thread:populate", %i[channel_id message_count] => ["db:load_config"] do |_, args|
    DiscourseDev::Thread.populate!(
      ignore_current_count: true,
      channel_id: args[:channel_id],
      message_count: args[:message_count],
    )
  end
end
