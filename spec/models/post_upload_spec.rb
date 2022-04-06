# frozen_string_literal: true

describe PostUpload do

  it { is_expected.to belong_to :post }
  it { is_expected.to belong_to :upload }

end
