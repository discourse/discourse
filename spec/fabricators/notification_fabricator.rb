Fabricator(:notification) do
  notification_type Notification.types[:mentioned]
  data '{"poison":"ivy","killer":"croc"}'
  user
  topic {|attrs| Fabricate(:topic, user: attrs[:user] ) }
end

Fabricator(:quote_notification, from: :notification) do
  notification_type Notification.types[:quoted]
  user
  topic {|attrs| Fabricate(:topic, user: attrs[:user] ) }
end

Fabricator(:private_message_notification, from: :notification) do
  notification_type Notification.types[:private_message]
  user
  topic {|attrs| Fabricate(:topic, user: attrs[:user] ) }
end
