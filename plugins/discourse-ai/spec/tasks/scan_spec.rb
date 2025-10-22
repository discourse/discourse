# frozen_string_literal: true

RSpec.describe "ai:spam rake tasks" do
  let!(:topic1) { Fabricate(:topic, created_at: 2.days.ago) }
  let!(:post1) { Fabricate(:post, topic: topic1, created_at: 2.days.ago) }
  let!(:topic2) { Fabricate(:topic, created_at: 1.hour.ago) }
  let!(:post2) { Fabricate(:post, topic: topic2, created_at: 1.hour.ago) }

  before { enable_current_plugin }

  describe "ai:spam:scan_posts" do
    it "enqueues posts within date range" do
      freeze_time do
        start_date = 1.day.ago.to_s
        end_date = Time.now.to_s

        expect_enqueued_with(job: :ai_spam_scan, args: { post_id: post2.id }) do
          Rake::Task["ai:spam:scan_posts"].invoke(start_date, end_date)
        end

        expect_not_enqueued_with(job: :ai_spam_scan, args: { post_id: post1.id })
      end
    end
  end

  describe "ai:spam:scan_topics" do
    it "enqueues first posts of topics within date range" do
      freeze_time do
        start_date = 1.day.ago.to_s
        end_date = Time.now.to_s

        expect_enqueued_with(job: :ai_spam_scan, args: { post_id: topic2.first_post.id }) do
          Rake::Task["ai:spam:scan_topics"].invoke(start_date, end_date)
        end

        expect_not_enqueued_with(job: :ai_spam_scan, args: { post_id: topic1.first_post.id })
      end
    end
  end
end
