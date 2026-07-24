# frozen_string_literal: true

RSpec.describe UploadGuardian do
  fab!(:user)
  fab!(:public_post, :post)
  fab!(:private_group, :group)
  fab!(:private_category) { Fabricate(:private_category, group: private_group) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category) }
  fab!(:private_post) { Fabricate(:post, topic: private_topic) }

  fab!(:non_secure_upload_without_access_control_post) do
    Fabricate(:upload, access_control_post: nil)
  end
  fab!(:secure_upload_without_access_control_post) do
    Fabricate(:secure_upload, access_control_post: nil)
  end
  fab!(:upload_with_visible_access_control_post) do
    Fabricate(:upload, access_control_post: public_post)
  end
  fab!(:secure_upload_with_hidden_access_control_post) do
    Fabricate(:secure_upload, access_control_post: private_post)
  end

  describe "#can_see_upload?" do
    it "returns true for a non-secure upload with no access_control_post" do
      expect(
        Guardian.new(user).can_see_upload?(non_secure_upload_without_access_control_post),
      ).to eq(true)
    end

    it "returns false for a secure upload with no access_control_post" do
      expect(Guardian.new(user).can_see_upload?(secure_upload_without_access_control_post)).to eq(
        false,
      )
    end

    it "returns true for an upload whose access_control_post the user can see" do
      expect(Guardian.new(user).can_see_upload?(upload_with_visible_access_control_post)).to eq(
        true,
      )

      private_group.add(user)

      expect(
        Guardian.new(user).can_see_upload?(secure_upload_with_hidden_access_control_post),
      ).to eq(true)
    end

    it "returns false for an upload whose access_control_post the user cannot see" do
      expect(
        Guardian.new(user).can_see_upload?(secure_upload_with_hidden_access_control_post),
      ).to eq(false)
    end
  end
end
