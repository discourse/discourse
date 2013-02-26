require 'spec_helper'

describe CategoryFeaturedTopic do

  it { should belong_to :category }
  it { should belong_to :topic }

end

