# frozen_string_literal: true

describe DiscourseAutomation::UserGlobalNotice do
  fab!(:user_1) { Fabricate(:user) }

  describe "creating duplicates" do
    it "prevents creating duplicates" do
      row = {
        user_id: user_1.id,
        notice: "foo",
        identifier: "bar",
        created_at: Time.now,
        updated_at: Time.now,
      }

      described_class.upsert(row)

      expect { described_class.upsert(row) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
