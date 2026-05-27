# frozen_string_literal: true

Fabricator(:group) { name { sequence(:name) { |n| "my_group_#{n}" } } }

Fabricator(:public_group, from: :group) do
  public_admission true
  public_exit true
end

Fabricator(:smtp_group, from: :group) do
  smtp_server "smtp.ponyexpress.com"
  smtp_port 587
  smtp_ssl_mode Group.smtp_ssl_modes[:starttls]
  smtp_enabled true
  email_username "discourseteam@ponyexpress.com"
  email_password "test"
end
