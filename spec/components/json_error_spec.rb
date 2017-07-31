require 'rails_helper'
require_dependency 'json_error'

shared_examples "a generic error" do
  let(:result) { creator.create_errors_json(obj) }

  it "should have a result object" do
    expect(result).to be_present
  end

  it "has a generic error message" do
    expect(result[:errors]).to eq([I18n.t('js.generic_error')])
  end
end

describe JsonError do

  let(:creator) { Object.new.extend(JsonError) }

  describe "with a nil argument" do
    it_behaves_like "a generic error" do
      let(:obj) { nil }
    end
  end

  describe "with an empty array" do
    it_behaves_like "a generic error" do
      let(:obj) { [] }
    end
  end

  describe "with an activerecord object with no errors" do
    it_behaves_like "a generic error" do
      let(:obj) { Fabricate.build(:user) }
    end
  end

  describe "with a string" do
    it "returns the string in the error format" do
      expect(creator.create_errors_json("test error")).to eq(errors: ["test error"])
    end
  end

  describe "an activerecord objec with errors" do
    let(:invalid_user) { User.new }
    it "returns the errors correctly" do
      expect(invalid_user).not_to be_valid
      result = creator.create_errors_json(invalid_user)
      expect(result).to be_present
      expect(result[:errors]).not_to be_blank
    end
  end

end
