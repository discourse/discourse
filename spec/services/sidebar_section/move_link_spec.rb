# frozen_string_literal: true

RSpec.describe SidebarSection::MoveLink do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:source_section_id) }
    it { is_expected.to validate_presence_of(:link_id) }
    it { is_expected.to validate_presence_of(:target_section_id) }
    it { is_expected.to allow_values(nil, 0, 5).for(:position) }
    it { is_expected.not_to allow_values(-1).for(:position) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :user)
    fab!(:source_section) { Fabricate(:sidebar_section, title: "Source", user: current_user) }
    fab!(:target_section) { Fabricate(:sidebar_section, title: "Target", user: current_user) }
    fab!(:moved_url) { Fabricate(:sidebar_url, name: "Moved", value: "/moved") }
    fab!(:first_target_url) { Fabricate(:sidebar_url, name: "First", value: "/first") }
    fab!(:second_target_url) { Fabricate(:sidebar_url, name: "Second", value: "/second") }
    fab!(:moved_link) do
      Fabricate(:sidebar_section_link, sidebar_section: source_section, linkable: moved_url)
    end
    fab!(:first_target_link) do
      Fabricate(:sidebar_section_link, sidebar_section: target_section, linkable: first_target_url)
    end
    fab!(:second_target_link) do
      Fabricate(:sidebar_section_link, sidebar_section: target_section, linkable: second_target_url)
    end

    let(:params) { { source_section_id:, link_id:, target_section_id:, position: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { current_user.guardian }
    let(:source_section_id) { source_section.id }
    let(:link_id) { moved_url.id }
    let(:target_section_id) { target_section.id }
    let(:position) { 0 }
    let(:messages) { MessageBus.track_publish("/refresh-sidebar-sections") { result } }

    context "when contract is invalid" do
      let(:position) { -1 }

      it { is_expected.to fail_a_contract }
    end

    context "when source section is not found" do
      let(:source_section_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:source_section) }
    end

    context "when target section is not found" do
      let(:target_section_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:target_section) }
    end

    context "when source and target sections are the same" do
      let(:target_section_id) { source_section.id }

      it { is_expected.to fail_a_policy(:sections_are_distinct) }
    end

    context "when acting user cannot edit the source section" do
      fab!(:current_user, :user)

      it { is_expected.to fail_a_policy(:can_edit_source_section) }
    end

    context "when acting user cannot edit the target section" do
      before { target_section.update!(public: true) }

      it { is_expected.to fail_a_policy(:can_edit_target_section) }
    end

    context "when the target section is full" do
      before { SiteSetting.max_sidebar_section_links = 2 }

      it { is_expected.to fail_a_policy(:target_section_has_room) }
    end

    context "when the link is not in the source section" do
      let(:link_id) { first_target_url.id }

      it { is_expected.to fail_to_find_a_model(:link) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "moves the existing link row to the target section" do
        expect { result }.to change { moved_link.reload.sidebar_section_id }.from(
          source_section.id,
        ).to(target_section.id)
      end

      it "keeps the same sidebar URL without destroying or recreating records" do
        expect { result }.to not_change { SidebarSectionLink.count }.and not_change {
                SidebarUrl.count
              }
        expect(moved_link.reload.linkable_id).to eq(moved_url.id)
        expect(SidebarUrl.exists?(moved_url.id)).to eq(true)
      end

      it "places the link first in the target section" do
        result
        expect(target_section.sidebar_urls.reload.map(&:id)).to eq(
          [moved_url.id, first_target_url.id, second_target_url.id],
        )
      end

      it "removes the link from the source section" do
        expect { result }.to change { source_section.sidebar_urls.reload.map(&:id) }.from(
          [moved_url.id],
        ).to([])
      end

      it "does not log a staff action" do
        expect { result }.not_to change { UserHistory.count }
      end

      it "does not publish a sidebar refresh" do
        expect(messages).to be_empty
      end

      context "with a middle position" do
        let(:position) { 1 }

        it "places the link between the existing target links" do
          result
          expect(target_section.sidebar_urls.reload.map(&:id)).to eq(
            [first_target_url.id, moved_url.id, second_target_url.id],
          )
        end
      end

      context "with no position" do
        let(:position) { nil }

        it "appends the link to the target section" do
          result
          expect(target_section.sidebar_urls.reload.map(&:id)).to eq(
            [first_target_url.id, second_target_url.id, moved_url.id],
          )
        end
      end

      context "with a position beyond the target size" do
        let(:position) { 100 }

        it "appends the link to the target section" do
          result
          expect(target_section.sidebar_urls.reload.map(&:id)).to eq(
            [first_target_url.id, second_target_url.id, moved_url.id],
          )
        end
      end
    end

    context "when the target section is public" do
      fab!(:current_user, :admin)

      before do
        source_section.update!(user: current_user)
        target_section.update!(public: true)
      end

      it { is_expected.to run_successfully }

      it "reassigns the link to the target section's user" do
        expect { result }.to change { moved_link.reload.user_id }.to(Discourse.system_user.id)
      end

      it "logs the staff action for the public section" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          action: UserHistory.actions[:update_public_sidebar_section],
          acting_user_id: current_user.id,
          subject: target_section.title,
        )
      end

      it "publishes a single sidebar refresh" do
        expect(messages.map(&:channel)).to eq(["/refresh-sidebar-sections"])
      end
    end

    context "when both sections are public" do
      fab!(:current_user, :admin)

      before do
        source_section.update!(public: true)
        target_section.update!(public: true)
      end

      it { is_expected.to run_successfully }

      it "logs the staff action for both sections" do
        expect { result }.to change { UserHistory.count }.by(2)
      end

      it "publishes a single sidebar refresh" do
        expect(messages.map(&:channel)).to eq(["/refresh-sidebar-sections"])
      end
    end
  end
end
