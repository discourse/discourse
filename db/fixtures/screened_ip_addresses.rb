ScreenedIpAddress.seed do |s|
  s.id = 1
  s.ip_address = "10.0.0.0/8"
  s.action_type = ScreenedIpAddress.actions[:do_nothing]
end

ScreenedIpAddress.seed do |s|
  s.id = 2
  s.ip_address = "192.168.0.0/16"
  s.action_type = ScreenedIpAddress.actions[:do_nothing]
end

ScreenedIpAddress.seed do |s|
  s.id = 3
  s.ip_address = "127.0.0.0/8"
  s.action_type = ScreenedIpAddress.actions[:do_nothing]
end

ScreenedIpAddress.seed do |s|
  s.id = 4
  s.ip_address = "172.16.0.0/12"
  s.action_type = ScreenedIpAddress.actions[:do_nothing]
end

# IPv6
ScreenedIpAddress.seed do |s|
  s.id = 5
  s.ip_address = "fc00::/7"
  s.action_type = ScreenedIpAddress.actions[:do_nothing]
end
