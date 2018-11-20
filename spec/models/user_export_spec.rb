require 'rails_helper'

RSpec.describe UserExport do
  let(:user) { Fabricate(:user) }

  describe '.remove_old_exports' do
    it 'should remove the right records' do
      export = UserExport.create!(
        file_name: "test",
        user: user,
        created_at: 3.days.ago
      )

      export2 = UserExport.create!(
        file_name: "test2",
        user: user,
        created_at: 1.day.ago
      )

      expect do
        UserExport.remove_old_exports
      end.to change { UserExport.count }.by(-1)

      expect(UserExport.exists?(id: export.id)).to eq(false)
      expect(UserExport.exists?(id: export2.id)).to eq(true)
    end
  end
end
