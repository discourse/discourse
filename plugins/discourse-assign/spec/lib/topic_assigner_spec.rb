# frozen_string_literal: true

RSpec.describe TopicAssigner do
  describe ".auto_assign" do
    let(:post) { instance_double(Post) }

    before { allow(Assigner).to receive(:auto_assign) }

    it "forwards force to Assigner as a keyword argument" do
      described_class.auto_assign(post, force: true)

      expect(Assigner).to have_received(:auto_assign).with(post, force: true)
    end

    it "forwards the default force value as a keyword argument" do
      described_class.auto_assign(post)

      expect(Assigner).to have_received(:auto_assign).with(post, force: false)
    end
  end
end
