require 'rails_helper'

describe PostReply do

  it { is_expected.to belong_to :post }
  it { is_expected.to belong_to :reply }

end
