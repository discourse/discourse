#!/usr/bin/env ruby
# frozen_string_literal: true

puts "👋 Welcome to the Discourse devcontainer! Let's get everything ready..."

puts "Setting permissions on volume mounts..."
system "sudo chown discourse .", exception: true
system "sudo chown discourse node_modules", exception: true
system "sudo chown -R postgres /shared/postgres_data", exception: true

puts "Starting services..."
fork do
  Process.daemon
  exec "sudo nohup /sbin/boot"
end

system "cp -n .vscode/settings.json.sample .vscode/settings.json", exception: true
system "cp -n .vscode/tasks.json.sample .vscode/tasks.json", exception: true

puts <<~TXT
  🎉 All done!

  Next steps:
    1. Cmd/Ctrl + Shift + B to run the shortcuts/boot-dev task
    2. Wait for the server to start
    3. Open your browser to http://localhost:4200
TXT
