require 'spec_helper'

describe TopicAllowedUser do
  it { should belong_to :user }
  it { should belong_to :topic }
end
