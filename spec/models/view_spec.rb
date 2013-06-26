require 'spec_helper'

describe View do

  it { should belong_to :parent }
  it { should belong_to :user }
  it { should validate_presence_of :parent_type }
  it { should validate_presence_of :parent_id }
  it { should validate_presence_of :ip_address }
  it { should validate_presence_of :viewed_at }


end
