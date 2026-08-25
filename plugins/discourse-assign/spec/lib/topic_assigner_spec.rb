# frozen_string_literal: true

RSpec.describe TopicAssigner do
  describe ".auto_assign" do
    let(:post) { instance_double(Post) }

    it "forwards force to Assigner as a keyword argument" do
      expect(Assigner).to receive(:auto_assign).with(post, force: true)

      described_class.auto_assign(post, force: true)
    end

    it "forwards the default force value as a keyword argument" do
      expect(Assigner).to receive(:auto_assign).with(post, force: false)

      described_class.auto_assign(post)
    end
  end
end
