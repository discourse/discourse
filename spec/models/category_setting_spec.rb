# frozen_string_literal: true

RSpec.describe CategorySetting do
  it { is_expected.to belong_to(:category) }

  it do
    is_expected.to validate_numericality_of(:num_auto_bump_daily)
      .only_integer
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end

  it do
    is_expected.to validate_numericality_of(:auto_bump_cooldown_days)
      .only_integer
      .is_greater_than_or_equal_to(0)
      .allow_nil
  end

  describe "#update_posting_review_mode!" do
    fab!(:category)
    fab!(:group)

    it "sets topic_posting_review_mode to everyone" do
      category.category_setting.update_posting_review_mode!(:topic, :everyone)
      expect(category.category_setting.reload.topic_posting_review_mode).to eq("everyone")
    end

    it "creates the right category_posting_review_group associations when topic_posting_review_mode is everyone_except" do
      category.category_setting.update_posting_review_mode!(
        :topic,
        :everyone_except,
        group_ids: [group.id],
      )

      review_groups = category.category_posting_review_groups.where(post_type: :topic)
      expect(review_groups.pluck(:group_id)).to contain_exactly(group.id)
    end

    it "creates the right category_posting_review_group associations when topic_posting_review_mode is no_one_except" do
      category.category_setting.update_posting_review_mode!(
        :topic,
        :no_one_except,
        group_ids: [group.id],
      )

      review_groups = category.category_posting_review_groups.where(post_type: :topic)
      expect(review_groups.pluck(:group_id)).to contain_exactly(group.id)
    end

    it "replaces existing category_posting_review_groups when topic_posting_review_mode is updated with new group_ids" do
      other_group = Fabricate(:group)
      category.category_setting.update_posting_review_mode!(
        :topic,
        :everyone_except,
        group_ids: [group.id],
      )
      category.category_setting.update_posting_review_mode!(
        :topic,
        :everyone_except,
        group_ids: [other_group.id],
      )

      review_groups = category.category_posting_review_groups.where(post_type: :topic)
      expect(review_groups.pluck(:group_id)).to contain_exactly(other_group.id)
    end

    it "clears category_posting_review_groups when topic_posting_review_mode is changed from everyone_except to everyone" do
      category.category_setting.update_posting_review_mode!(
        :topic,
        :everyone_except,
        group_ids: [group.id],
      )
      category.category_setting.update_posting_review_mode!(:topic, :everyone)

      expect(category.category_posting_review_groups.where(post_type: :topic).count).to eq(0)
    end

    it "raises ArgumentError when group_ids are provided for everyone topic_posting_review_mode" do
      expect {
        category.category_setting.update_posting_review_mode!(
          :topic,
          :everyone,
          group_ids: [group.id],
        )
      }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when group_ids are provided for no_one topic_posting_review_mode" do
      expect {
        category.category_setting.update_posting_review_mode!(
          :topic,
          :no_one,
          group_ids: [group.id],
        )
      }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when group_ids are blank for everyone_except topic_posting_review_mode" do
      expect {
        category.category_setting.update_posting_review_mode!(:topic, :everyone_except)
      }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when group_ids are blank for no_one_except topic_posting_review_mode" do
      expect {
        category.category_setting.update_posting_review_mode!(:topic, :no_one_except)
      }.to raise_error(ArgumentError)
    end
  end
end
