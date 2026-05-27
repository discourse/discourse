# frozen_string_literal: true

RSpec.describe Category::Action::EagerLoadAssociations do
  describe ".call" do
    subject(:action) { described_class.call(categories:, guardian:) }

    fab!(:user)
    fab!(:category)

    let(:guardian) { Guardian.new(user) }
    let(:categories) { [category] }

    it "preloads associations without errors" do
      expect { action }.not_to raise_error
    end

    context "when categories is empty" do
      let(:categories) { [] }

      it "handles empty categories" do
        expect { action }.not_to raise_error
      end
    end

    context "with custom fields configured" do
      before do
        allow(Site).to receive(:preloaded_category_custom_fields).and_return(%w[custom_field])
        allow(Category).to receive(:preload_custom_fields)
      end

      it "preloads custom fields" do
        action
        expect(Category).to have_received(:preload_custom_fields).with(categories, %w[custom_field])
      end
    end
  end
end
