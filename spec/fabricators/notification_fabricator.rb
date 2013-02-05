Fabricator(:notification) do
  notification_type Notification.Types[:mentioned]
  data '{"poison":"ivy","killer":"croc"}'
  user
  topic {|attrs| Fabricate(:topic, user: attrs[:user] ) }
end

Fabricator(:quote_notification, from: :notification) do
  notification_type Notification.Types[:quoted]
  user
  topic {|attrs| Fabricate(:topic, user: attrs[:user] ) }
end

Fabricator(:private_message_notification, from: :notification) do
  notification_type Notification.Types[:private_message]
  user
  topic {|attrs| Fabricate(:topic, user: attrs[:user] ) }
end
