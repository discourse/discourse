require 'spec_helper'
require 'disk_space'

describe DiskSpace do
  let(:private_api) { %i(free used) }

  it 'hides private api' do
    expect(
      described_class.singleton_class.private_instance_methods(false)
    ).to eq private_api
    expect private_api.none? { |m| described_class.respond_to?(m) }
  end
end
