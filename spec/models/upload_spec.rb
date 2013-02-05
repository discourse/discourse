require 'spec_helper'

describe Upload do

  it { should belong_to :user }
  it { should belong_to :topic }
  it { should validate_presence_of :original_filename }
  it { should validate_presence_of :filesize }
end
