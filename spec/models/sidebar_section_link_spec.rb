# frozen_string_literal: true

RSpec.describe SidebarSectionLink do
  fab!(:user) { Fabricate(:user) }

  describe '#linkable_type' do
    it "is not valid when linkable_type is not supported" do
      sidebar_section_link = SidebarSectionLink.new(user: user, linkable_id: 1, linkable_type: 'sometype')

      expect(sidebar_section_link.valid?).to eq(false)

      expect(sidebar_section_link.errors[:linkable_type]).to eq([
        I18n.t("activerecord.errors.models.sidebar_section_link.attributes.linkable_type.invalid")
      ])
    end

    it "is not valid when linkable_type is Tag and SiteSetting.tagging_enabled is false" do
      SiteSetting.tagging_enabled = false
      sidebar_section_link = SidebarSectionLink.new(user: user, linkable_id: 1, linkable_type: 'Tag')

      expect(sidebar_section_link.valid?).to eq(false)

      expect(sidebar_section_link.errors[:linkable_type]).to eq([
        I18n.t("activerecord.errors.models.sidebar_section_link.attributes.linkable_type.invalid")
      ])
    end
  end
end
