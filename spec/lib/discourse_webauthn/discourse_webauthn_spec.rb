# frozen_string_literal: true

RSpec.describe DiscourseWebauthn do
  describe "#origin" do
    it "returns the current hostname" do
      expect(DiscourseWebauthn.origin).to eq("http://test.localhost")
    end

    context "with subfolder" do
      it "does not append /forum to origin" do
        set_subfolder "/forum"
        expect(DiscourseWebauthn.origin).to eq("http://test.localhost")
      end
    end
  end
end
