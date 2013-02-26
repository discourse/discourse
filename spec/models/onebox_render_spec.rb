require 'spec_helper'

describe OneboxRender do

  it { should validate_presence_of :url }
  it { should validate_presence_of :cooked }
  it { should validate_presence_of :expires_at }
  it { should have_many :post_onebox_renders }
  it { should have_many :posts }

end
