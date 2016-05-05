require 'rails_helper'
require 'has_errors'

describe HasErrors do

  class ErrorTestClass
    include HasErrors
  end

  let(:error_test) { ErrorTestClass.new }
  let(:title_error) { "Title can't be blank" }

  # No title is invalid
  let(:invalid_topic) { Fabricate.build(:topic, title: '') }

  it "has no errors by default" do
    expect(error_test.errors).to be_blank
  end

  context "validate_child" do
    it "adds the errors from invalid AR objects" do
      expect(error_test.validate_child(invalid_topic)).to eq(false)
      expect(error_test.errors).to be_present
      expect(error_test.errors[:base]).to include(title_error)
    end

    it "doesn't add the errors from valid AR objects" do
      topic = Fabricate.build(:topic)
      expect(error_test.validate_child(topic)).to eq(true)
      expect(error_test.errors).to be_blank
    end
  end

  context "rollback_from_errors!" do
    it "triggers a rollback" do
      invalid_topic.valid?

      expect(-> { error_test.rollback_from_errors!(invalid_topic) }).to raise_error(ActiveRecord::Rollback)
      expect(error_test.errors).to be_present
      expect(error_test.errors[:base]).to include(title_error)
    end
  end

  context "rollback_with_error!" do
    it "triggers a rollback" do

      expect(-> {
        error_test.rollback_with!(invalid_topic, :too_many_users)
      }).to raise_error(ActiveRecord::Rollback)
      expect(error_test.errors).to be_present
      expect(error_test.errors[:base]).to include("You can only send warnings to one user at a time.")
    end
  end

end
