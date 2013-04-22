shared_examples_for "a versioned model" do
  let(:model) { Fabricate(described_class.to_s.downcase) }

  it 'should be versioned' do
    model.should respond_to(:version)
    model.version.should == 1
  end
end
