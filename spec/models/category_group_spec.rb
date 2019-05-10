# frozen_string_literal: true

require 'rails_helper'

describe CategoryGroup do

  describe '#permission_types' do
    context "verify enum sequence" do
      before do
        @permission_types = CategoryGroup.permission_types
      end

      it "'full' should be at 1st position" do
        expect(@permission_types[:full]).to eq(1)
      end

      it "'readonly' should be at 3rd position" do
        expect(@permission_types[:readonly]).to eq(3)
      end
    end
  end
end
