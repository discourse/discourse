require 'rails_helper'
require_relative 'fabricators/automation_fabricator'

DiscourseAutomation::Scriptable.add('something_about_us') do
  script { |context| puts context.to_json }
end

DiscourseAutomation::Scriptable.add('nothing_about_us') do
end
