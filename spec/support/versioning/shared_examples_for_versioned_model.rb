shared_examples_for "a versioned model" do
  let(:model) { Fabricate(described_class.to_s.downcase) }

  it 'should be versioned' do
    expect(model).to respond_to(:version)
    expect(model.version).to eq(1)
  end
end
