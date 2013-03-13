shared_examples_for "a versioned model" do
  let(:model) { Fabricate(described_class.to_s.downcase) }
  let(:first_version_at) { model.last_version_at }

  it 'should be versioned' do
    model.should respond_to(:version)
  end

  it 'has an initial version of 1' do
    model.version.should == 1
  end
end
