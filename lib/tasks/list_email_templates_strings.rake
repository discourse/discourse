# frozen_string_literal: true

task "list_email_templates_strings" => :environment do
  puts EmailTemplatesFinder.list
end
