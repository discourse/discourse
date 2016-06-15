require 'rails_helper'

describe WebHookEventType do
  it { is_expected.to validate_presence_of :name }
end
