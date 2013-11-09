require 'spec_helper'

describe PostDetail do
  it { should belong_to :post }

  it { should validate_presence_of :key }
  it { should validate_presence_of :value }
  it { should validate_uniqueness_of(:key).scoped_to(:post_id) }
end
