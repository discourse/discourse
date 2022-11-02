# frozen_string_literal: true

RSpec.describe CategoryChannel do
  subject(:channel) { Fabricate.build(:category_channel) }

  it_behaves_like "a chat channel model"

  it { is_expected.to delegate_method(:read_restricted?).to(:category) }
  it { is_expected.to delegate_method(:url).to(:chatable).with_prefix }

  describe "#category_channel?" do
    it "always returns true" do
      expect(channel).to be_a_category_channel
    end
  end

  describe "#public_channel?" do
    it "always returns true" do
      expect(channel).to be_a_public_channel
    end
  end

  describe "#chatable_has_custom_fields?" do
    it "always returns true" do
      expect(channel).to be_a_chatable_has_custom_fields
    end
  end

  describe "#direct_message_channel?" do
    it "always returns false" do
      expect(channel).not_to be_a_direct_message_channel
    end
  end

  describe "#allowed_user_ids" do
    it "always returns nothing" do
      expect(channel.allowed_user_ids).to be_nil
    end
  end

  describe "#allowed_group_ids" do
    subject(:allowed_group_ids) { channel.allowed_group_ids }

    context "when channel is public" do
      let(:public_category) { Fabricate(:category, read_restricted: false) }
      let(:channel) { Fabricate(:category_channel, chatable: public_category) }

      it "returns nothing" do
        expect(allowed_group_ids).to be_nil
      end
    end

    context "when channel is not public" do
      let(:staff_groups) { Group::AUTO_GROUPS.slice(:staff, :moderators, :admins).values }
      let(:group) { Fabricate(:group) }
      let(:private_category) { Fabricate(:private_category, group: group) }
      let(:channel) { Fabricate(:category_channel, chatable: private_category) }

      it "returns groups with access to the associated category" do
        expect(allowed_group_ids).to contain_exactly(*staff_groups, group.id)
      end
    end
  end

  describe "#title" do
    subject(:title) { channel.title(nil) }

    before { channel.name = custom_name }

    context "when 'name' is set" do
      let(:custom_name) { "a custom name" }

      it "returns the name that has been set on the channel" do
        expect(title).to eq(custom_name)
      end
    end

    context "when 'name' is not set" do
      let(:custom_name) { nil }

      it "returns the name from the associated category" do
        expect(title).to eq(channel.category.name)
      end
    end
  end
end
