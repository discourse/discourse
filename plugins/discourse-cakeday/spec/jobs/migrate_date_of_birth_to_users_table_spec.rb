# frozen_string_literal: true

require "rails_helper"

describe Jobs::MigrateDateOfBirthToUsersTable do
  let(:user) { Fabricate(:user) }

  context "with YYYY-MM-DD" do
    it "should migrate successfully" do
      user.custom_fields["date_of_birth"] = "1904-05-02"
      user.save!

      described_class.new.execute({})

      expect(user.reload.date_of_birth).to eq(Date.new(1904, 05, 02))
    end
  end

  context "with DD-MM-YYYY" do
    it "should migrate successfully" do
      user.custom_fields["date_of_birth"] = "02-05-1904"
      user.save!

      described_class.new.execute({})

      expect(user.reload.date_of_birth).to eq(Date.new(1904, 05, 02))
    end
  end

  context "with DD/MM/YYYY" do
    it "should migrate successfully" do
      user.custom_fields["date_of_birth"] = "02/05/1904"
      user.save!

      described_class.new.execute({})

      expect(user.reload.date_of_birth).to eq(Date.new(1904, 05, 02))
    end
  end

  context "when custom field date is invalid" do
    it "should ignore the error" do
      user.custom_fields["date_of_birth"] = "02/13/1904"
      user.save!

      described_class.new.execute({})

      expect(user.reload.date_of_birth).to eq(nil)
    end
  end

  context "when custom field date is blank" do
    it "should remove the custom field" do
      user.custom_fields["date_of_birth"] = ""
      user.save!

      expect(UserCustomField.find_by(user_id: user.id).value).to eq("")

      described_class.new.execute({})

      expect(user.reload.date_of_birth).to eq(nil)

      expect(UserCustomField.find_by(user_id: user.id)).to eq(nil)
    end
  end
end
