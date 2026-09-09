# frozen_string_literal: true

RSpec.describe SidebarSection::ReorderLinks do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:section_id) }
    it { is_expected.to validate_presence_of(:links_order) }

    it "coerces links_order values to integers and discards non-numeric ones" do
      contract = described_class.new(links_order: ["1", "junk", 2])
      contract.validate
      expect(contract.links_order).to eq([1, 2])
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :user)
    fab!(:section) { Fabricate(:sidebar_section, user: current_user) }
    fab!(:first_url) { Fabricate(:sidebar_url, name: "First", value: "/first") }
    fab!(:second_url) { Fabricate(:sidebar_url, name: "Second", value: "/second") }
    fab!(:first_link) do
      Fabricate(:sidebar_section_link, sidebar_section: section, linkable: first_url)
    end
    fab!(:second_link) do
      Fabricate(:sidebar_section_link, sidebar_section: section, linkable: second_url)
    end

    let(:params) { { section_id:, links_order: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { current_user.guardian }
    let(:section_id) { section.id }
    let(:links_order) { [second_url.id, first_url.id] }
    let(:messages) { MessageBus.track_publish("/refresh-sidebar-sections") { result } }

    context "when contract is invalid" do
      let(:links_order) { [] }

      it { is_expected.to fail_a_contract }
    end

    context "when section is not found" do
      let(:section_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:section) }
    end

    context "when acting user cannot edit the section" do
      fab!(:current_user, :user)

      it { is_expected.to fail_a_policy(:can_edit_section) }
    end

    context "when links_order does not cover every link" do
      let(:links_order) { [first_url.id] }

      it { is_expected.to fail_a_policy(:order_covers_every_link) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "applies the requested order" do
        expect { result }.to change { section.sidebar_urls.reload.map(&:id) }.from(
          [first_url.id, second_url.id],
        ).to([second_url.id, first_url.id])
      end

      it "does not log a staff action" do
        expect { result }.not_to change { UserHistory.count }
      end

      it "does not publish a sidebar refresh" do
        expect(messages).to be_empty
      end
    end

    context "when the section is public" do
      fab!(:current_user, :admin)

      before { section.update!(public: true) }

      it { is_expected.to run_successfully }

      it "applies the requested order" do
        expect { result }.to change { section.sidebar_urls.reload.map(&:id) }.to(
          [second_url.id, first_url.id],
        )
      end

      it "logs the staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          action: UserHistory.actions[:update_public_sidebar_section],
          acting_user_id: current_user.id,
          subject: section.title,
        )
      end

      it "publishes a sidebar refresh" do
        expect(messages.map(&:channel)).to eq(["/refresh-sidebar-sections"])
      end
    end
  end
end
