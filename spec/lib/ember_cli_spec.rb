# frozen_string_literal: true

describe EmberCli do
  describe "#ember_version" do
    it "works" do
      expect(EmberCli.ember_version).to match(/\A\d+\.\d+/)
    end
  end
end
