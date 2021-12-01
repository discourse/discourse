require 'rails_helper'

DiscourseAutomation::Scriptable.add('something_about_us') do
  script { |context| puts context.to_json }
  triggerables [DiscourseAutomation::Triggerable::API_CALL]
end

DiscourseAutomation::Scriptable.add('nothing_about_us') do
  triggerables [DiscourseAutomation::Triggerable::API_CALL]
end
