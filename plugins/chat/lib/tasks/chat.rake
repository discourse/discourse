# frozen_string_literal: true

if Discourse.allow_dev_populate?
  desc "Generates sample messages in channels"
  task "chat:message:populate", %i[channel_id count] => ["db:load_config"] do |_, args|
    DiscourseDev::Message.populate!(channel_id: args[:channel_id], count: args[:count])
  end

  desc "Generates random channels from categories"
  task "chat:category_channel:populate" => ["db:load_config"] do |_, args|
    DiscourseDev::CategoryChannel.populate!
  end

  desc "Creates a thread with sample messages in a channel"
  task "chat:thread:populate", %i[channel_id count] => ["db:load_config"] do |_, args|
    DiscourseDev::Thread.populate!(channel_id: args[:channel_id], count: args[:count])
  end
end
