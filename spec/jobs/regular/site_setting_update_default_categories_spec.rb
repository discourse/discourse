# frozen_string_literal: true

describe Jobs::SiteSettingUpdateDefaultCategories do
  subject(:job) { described_class.new }

  context "when logged in as an admin" do
    context "with default categories" do
      fab!(:user1, :user)
      fab!(:user2, :user)
      fab!(:staged_user, :staged)
      let(:watching) { NotificationLevels.all[:watching] }
      let(:tracking) { NotificationLevels.all[:tracking] }

      let(:category_ids) { 3.times.collect { Fabricate(:category).id } }

      before do
        SiteSetting.default_categories_watching = category_ids.first(2).join("|")

        CategoryUser.create!(
          category_id: category_ids.last,
          notification_level: tracking,
          user: user2,
        )
      end

      it "should update existing users user preference" do
        job.execute(
          id: "default_categories_watching",
          value: category_ids.last(2).join("|"),
          previous_value: category_ids.first(2).join("|"),
        )

        expect(
          CategoryUser.where(category_id: category_ids.first, notification_level: watching).count,
        ).to eq(0)

        expect(
          CategoryUser.where(category_id: category_ids.last, notification_level: watching).count,
        ).to eq(User.real.where(staged: false).count - 1)

        # Set default_categories_watching to the new value otherwise
        # new CategoryUser records will be created with the wrong value
        SiteSetting.default_categories_watching = category_ids.last(2).join("|")

        topic = Fabricate(:topic, category_id: category_ids.last)
        topic_user1 =
          Fabricate(
            :topic_user,
            topic: topic,
            notification_level: TopicUser.notification_levels[:watching],
            notifications_reason_id: TopicUser.notification_reasons[:auto_watch_category],
          )
        topic_user2 =
          Fabricate(
            :topic_user,
            topic: topic,
            notification_level: TopicUser.notification_levels[:watching],
            notifications_reason_id: TopicUser.notification_reasons[:user_changed],
          )

        job.execute(
          id: "default_categories_watching",
          value: "",
          previous_value: category_ids.last(2).join("|"),
        )

        expect(
          CategoryUser.where(category_id: category_ids, notification_level: watching).count,
        ).to eq(0)
        expect(topic_user1.reload.notification_level).to eq(TopicUser.notification_levels[:regular])
        expect(topic_user2.reload.notification_level).to eq(
          TopicUser.notification_levels[:watching],
        )
      end
    end
  end
end
