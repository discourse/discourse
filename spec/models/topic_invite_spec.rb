require 'spec_helper'

describe TopicInvite do

  it { should belong_to :topic }
  it { should belong_to :invite }
  it { should validate_presence_of :topic_id }
  it { should validate_presence_of :invite_id }

end
