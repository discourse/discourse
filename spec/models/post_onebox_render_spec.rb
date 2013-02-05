require 'spec_helper'

describe PostOneboxRender do

  it { should belong_to :onebox_render }
  it { should belong_to :post }

end
