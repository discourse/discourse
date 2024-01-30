# frozen_string_literal: true

RSpec.describe BasicGroupSerializer do
  subject(:serializer) { described_class.new(group, scope: guardian, root: false) }

  let(:guardian) { Guardian.new }
  fab!(:group)

  describe "#display_name" do
    describe "automatic group" do
      let(:group) { Group.find(1) }

      it "should include the display name" do
        expect(serializer.display_name).to eq(I18n.t("groups.default_names.admins"))
      end
    end

    describe "normal group" do
      fab!(:group)

      it "should not include the display name" do
        expect(serializer.display_name).to eq(nil)
      end
    end
  end

  describe "#bio_raw" do
    subject(:serializer) do
      described_class.new(group, scope: guardian, root: false, owner_group_ids: [group.id])
    end

    fab!(:group) { Fabricate(:group, bio_raw: "testing :slightly_smiling_face:") }

    describe "group owner" do
      it "should include bio_raw" do
        expect(serializer.as_json[:bio_raw]).to eq("testing :slightly_smiling_face:")
        expect(serializer.as_json[:bio_excerpt]).to start_with("testing <img")
      end
    end
  end

  describe "#has_messages" do
    fab!(:group) { Fabricate(:group, has_messages: true) }

    describe "for a staff user" do
      let!(:guardian) { Guardian.new(Fabricate(:moderator)) }

      it "should be present" do
        expect(serializer.as_json[:has_messages]).to eq(true)
      end
    end

    describe "for a group user" do
      fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
      let(:guardian) { Guardian.new(user) }

      before { group.add(user) }

      it "should be present" do
        expect(serializer.as_json[:has_messages]).to eq(true)
      end
    end

    describe "for a normal user" do
      let(:guardian) { Guardian.new(Fabricate(:user)) }

      it "should not be present" do
        expect(serializer.as_json[:has_messages]).to eq(nil)
      end
    end
  end

  describe "#can_see_members" do
    fab!(:group) { Fabricate(:group, members_visibility_level: Group.visibility_levels[:members]) }

    describe "for a group user" do
      fab!(:user)
      let(:guardian) { Guardian.new(user) }

      before { group.add(user) }

      it "should be true" do
        expect(serializer.as_json[:can_see_members]).to eq(true)
      end
    end

    describe "for a normal user" do
      let(:guardian) { Guardian.new(Fabricate(:user)) }

      it "should be false" do
        expect(serializer.as_json[:can_see_members]).to eq(false)
      end
    end
  end
end
