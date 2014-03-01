require 'spec_helper'
require_dependency 'post_revision'

describe PostRevision do

  it { should belong_to :user }
  it { should belong_to :post }

end
