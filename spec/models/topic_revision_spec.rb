require 'spec_helper'
require_dependency 'topic_revision'

describe TopicRevision do

  it { should belong_to :user }
  it { should belong_to :topic }

end
