# frozen_string_literal: true

describe Jobs::SiteSettingUpdateDefaultTags do
  subject(:job) { described_class.new }

  context "when logged in as an admin" do
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

        expect(TagUser.where(tag_id: tags.first.id, notification_level: watching).count).to eq(0)
        expect(TagUser.where(tag_id: tags.last.id, notification_level: watching).count).to eq(
          User.real.where(staged: false).count - 1,
        )
      end

      it "should publish a MessageBus informing the correct groups" do
        messages =
          MessageBus.track_publish("/site_setting/default_tags_watching/process") do
            job.execute(
              id: "default_tags_watching",
              value: tags.last(2).pluck(:name).join("|"),
              previous_value: tags.first(2).pluck(:name).join("|"),
            )
          end

        expect(messages[0][:data][:group_ids]).to eq([Group::AUTO_GROUPS[:admins]])
        expect(messages[0][:data][:status]).to eq("completed")
      end
    end
  end
end
