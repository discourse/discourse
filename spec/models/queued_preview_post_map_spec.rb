require 'rails_helper'

describe QueuedPreviewPostMap do

  it { is_expected.to belong_to :post }
  it { is_expected.to belong_to :topic }
  it { is_expected.to belong_to :queued_post }

end
