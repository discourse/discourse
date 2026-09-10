# frozen_string_literal: true

RSpec.describe ReviewableBundledActionSerializer do
  fab!(:admin)
  fab!(:reviewable, :reviewable_user)

  it "includes the secondary flag only on secondary bundles" do
    reviewable.target.update!(uploaded_avatar_id: Fabricate(:upload).id)

    json =
      reviewable
        .actions_for(admin.guardian)
        .bundles
        .map { |bundle| described_class.new(bundle, root: false).as_json }

    expect(json.select { |bundle| bundle.key?(:secondary) }).to contain_exactly(
      include(id: "#{reviewable.id}-user-remove_avatar", secondary: true),
    )
  end
end
