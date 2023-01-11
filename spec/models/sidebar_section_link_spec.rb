# frozen_string_literal: true

RSpec.describe SidebarSectionLink do
  fab!(:user) { Fabricate(:user) }

  describe "Validations" do
    it "is not valid when linkable already exists for the current user" do
      category_sidebar_section_link = Fabricate(:category_sidebar_section_link, user: user)

      sidebar_section_link =
        SidebarSectionLink.new(user: user, linkable: category_sidebar_section_link.linkable)

      expect(sidebar_section_link.valid?).to eq(false)
      expect(sidebar_section_link.errors.details[:user_id][0][:error]).to eq(:taken)
    end

    describe "#linkable_type" do
      it "is not valid when linkable_type is not supported" do
        sidebar_section_link =
          SidebarSectionLink.new(user: user, linkable_id: 1, linkable_type: "sometype")

        expect(sidebar_section_link.valid?).to eq(false)

        expect(sidebar_section_link.errors[:linkable_type]).to eq(
          [
            I18n.t(
              "activerecord.errors.models.sidebar_section_link.attributes.linkable_type.invalid",
            ),
          ],
        )
      end

      it "is not valid when linkable_type is Tag and SiteSetting.tagging_enabled is false" do
        SiteSetting.tagging_enabled = false
        sidebar_section_link =
          SidebarSectionLink.new(user: user, linkable_id: 1, linkable_type: "Tag")

        expect(sidebar_section_link.valid?).to eq(false)

        expect(sidebar_section_link.errors[:linkable_type]).to eq(
          [
            I18n.t(
              "activerecord.errors.models.sidebar_section_link.attributes.linkable_type.invalid",
            ),
          ],
        )
      end
    end
  end
end
