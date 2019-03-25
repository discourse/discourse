require 'google/apis/gmail_v1'
require 'googleauth'

desc "generate refresh token for gmail credentials"
task "gmail:credentials", [:group_name] => [:environment] do |_, args|
  group = Group.find_by(name: args[:group_name])
  if !group
    puts "ERROR: Expecting rake gmail:credentials[group_name]"
    exit 1
  end

  credentials = GmailSync::credentials_for(group)
  puts "Authorize Discourse at #{credentials.authorization_uri.to_s}"

  puts "Enter the code:"
  credentials.code = STDIN.gets
  credentials.fetch_access_token!

  puts "Your access token is #{credentials.access_token}."
  group.custom_fields[GmailSync::TOKEN_FIELD] = credentials.access_token
  group.save_custom_fields
end
