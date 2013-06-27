require 'spec_helper'

describe PostUpload do

  it { should belong_to :post }
  it { should belong_to :upload }

end
