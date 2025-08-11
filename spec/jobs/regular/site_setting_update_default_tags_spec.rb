# frozen_string_literal: true

describe Jobs::SiteSettingUpdateDefaultTags do
  subject(:job) { described_class.new }

  fab!(:admin)
  context "when logged in as an admin" do
    before { sign_in(admin) }

    context "with default tags" do
      fab!(:user1, :user)
      fab!(:user2, :user)
      fab!(:staged_user, :staged)
      let(:watching) { NotificationLevels.all[:watching] }
      let(:tracking) { NotificationLevels.all[:tracking] }

      let(:tags) { 3.times.collect { Fabricate(:tag) } }
      before do
        SiteSetting.default_tags_watching = tags.first(2).pluck(:name).join("|")
        TagUser.create!(tag_id: tags.last.id, notification_level: tracking, user: user2)
      end

      it "should update existing users user preference" do
        job.execute(
          id: "default_tags_watching",
          value: tags.last(2).pluck(:name).join("|"),
          previous_value: tags.first(2).pluck(:name).join("|"),
        )

        SiteSetting.default_tags_watching = tags.last(2).pluck(:name).join("|")

        expect(TagUser.where(tag_id: tags.first.id, notification_level: watching).count).to eq(0)
        expect(TagUser.where(tag_id: tags.last.id, notification_level: watching).count).to eq(
          User.real.where(staged: false).count - 1,
        )
      end
    end
  end
end
