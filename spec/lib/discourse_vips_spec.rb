# frozen_string_literal: true

RSpec.describe DiscourseVips do
  describe ".version" do
    it "returns a cache version" do
      expect(described_class.version).to match(/\A\d+\.\d+\.\d+-8\.\d+\.\d+\z/)
    end
  end
end
