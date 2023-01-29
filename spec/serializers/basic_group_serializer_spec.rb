# frozen_string_literal: true

RSpec.describe BasicGroupSerializer do
  let(:guardian) { Guardian.new }
  fab!(:group) { Fabricate(:group) }
  subject { described_class.new(group, scope: guardian, root: false) }

  describe "#display_name" do
    describe "automatic group" do
      let(:group) { Group.find(1) }

      it "should include the display name" do
        expect(subject.display_name).to eq(I18n.t("groups.default_names.admins"))
      end
    end

    describe "normal group" do
      fab!(:group) { Fabricate(:group) }

      it "should not include the display name" do
        expect(subject.display_name).to eq(nil)
      end
    end
  end

  describe "#bio_raw" do
    fab!(:group) { Fabricate(:group, bio_raw: "testing :slightly_smiling_face:") }

    subject do
      described_class.new(group, scope: guardian, root: false, owner_group_ids: [group.id])
    end

    describe "group owner" do
      it "should include bio_raw" do
        expect(subject.as_json[:bio_raw]).to eq("testing :slightly_smiling_face:")
        expect(subject.as_json[:bio_excerpt]).to start_with("testing <img")
      end
    end
  end

  describe "#has_messages" do
    fab!(:group) { Fabricate(:group, has_messages: true) }

    before { Group.refresh_automatic_groups! }

    describe "for a staff user" do
      let(:guardian) { Guardian.new(Fabricate(:moderator)) }

      it "should be present" do
        Group.refresh_automatic_groups!
        expect(subject.as_json[:has_messages]).to eq(true)
      end
    end

    describe "for a group user" do
      fab!(:user) { Fabricate(:user) }
      let(:guardian) { Guardian.new(user) }

      before { group.add(user) }

      it "should be present" do
        expect(subject.as_json[:has_messages]).to eq(true)
      end
    end

    describe "for a normal user" do
      let(:guardian) { Guardian.new(Fabricate(:user)) }

      it "should not be present" do
        expect(subject.as_json[:has_messages]).to eq(nil)
      end
    end
  end

  describe "#can_see_members" do
    fab!(:group) { Fabricate(:group, members_visibility_level: Group.visibility_levels[:members]) }

    describe "for a group user" do
      fab!(:user) { Fabricate(:user) }
      let(:guardian) { Guardian.new(user) }

      before { group.add(user) }

      it "should be true" do
        expect(subject.as_json[:can_see_members]).to eq(true)
      end
    end

    describe "for a normal user" do
      let(:guardian) { Guardian.new(Fabricate(:user)) }

      it "should be false" do
        expect(subject.as_json[:can_see_members]).to eq(false)
      end
    end
  end
end
