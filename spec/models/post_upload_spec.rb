# frozen_string_literal: true

require 'rails_helper'

describe PostUpload do

  it { is_expected.to belong_to :post }
  it { is_expected.to belong_to :upload }

end
