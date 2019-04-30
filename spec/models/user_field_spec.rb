# frozen_string_literal: true

require 'rails_helper'

describe UserField do
  describe "doesn't validate presence of name if field type is 'confirm'" do
    subject { described_class.new(field_type: 'confirm') }
    it { is_expected.not_to validate_presence_of :name }
  end

  describe "validates presence of name for other field types" do
    subject { described_class.new(field_type: 'dropdown') }
    it { is_expected.to validate_presence_of :name }
  end
end
