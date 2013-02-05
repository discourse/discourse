require 'spec_helper'

describe PostReply do

  it { should belong_to :post }
  it { should belong_to :reply }

end
