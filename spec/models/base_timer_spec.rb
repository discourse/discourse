# frozen_string_literal: true

RSpec.describe BaseTimer, type: :model do
  describe "single table inheritance" do
    it "is valid with a type of TopicTimer" do
      base_timer = Fabricate(:base_timer, type: "TopicTimer")
      expect(base_timer.is_a?(TopicTimer)).to eq(true)
    end

    it "will raise an error if constructed with invalid type" do
      expect do Fabricate(:base_timer, type: "FooBar") end.to raise_error(
        ActiveRecord::SubclassNotFound,
      )
    end
  end
end
