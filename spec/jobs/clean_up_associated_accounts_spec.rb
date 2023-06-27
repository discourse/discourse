# frozen_string_literal: true

RSpec.describe Jobs::CleanUpAssociatedAccounts do
  subject(:job) { Jobs::CleanUpAssociatedAccounts.new.execute({}) }

  it "deletes the correct records" do
    freeze_time

    last_week =
      UserAssociatedAccount.create!(
        provider_name: "twitter",
        provider_uid: "1",
        updated_at: 7.days.ago,
      )
    today =
      UserAssociatedAccount.create!(
        provider_name: "twitter",
        provider_uid: "12",
        updated_at: 12.hours.ago,
      )
    connected =
      UserAssociatedAccount.create!(
        provider_name: "twitter",
        provider_uid: "123",
        user: Fabricate(:user),
        updated_at: 12.hours.ago,
      )

    expect { job }.to change { UserAssociatedAccount.count }.by(-1)
    expect(UserAssociatedAccount.all).to contain_exactly(today, connected)
  end
end
