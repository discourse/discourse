# frozen_string_literal: true

RSpec.describe UserStatCountUpdater do
  fab!(:user)
  fab!(:user_stat) { user.user_stat }
  fab!(:post)
  fab!(:post_2) { Fabricate(:post, topic: post.topic) }

  let(:fake_logger) { FakeLogger.new }

  before do
    Rails.logger.broadcast_to(fake_logger)
    SiteSetting.verbose_user_stat_count_logging = true
  end

  after { Rails.logger.stop_broadcasting_to(fake_logger) }

  it "should log the exception when a negative count is inserted" do
    UserStatCountUpdater.decrement!(post, user_stat: user_stat)

    expect(fake_logger.warnings.last).to match("topic_count")
    expect(fake_logger.warnings.last).to match(post.id.to_s)

    UserStatCountUpdater.decrement!(post_2, user_stat: user_stat)

    expect(fake_logger.warnings.last).to match("post_count")
    expect(fake_logger.warnings.last).to match(post_2.id.to_s)
  end

  it "should log the exception when a negative count will be inserted but 0 is used instead" do
    UserStatCountUpdater.set!(user_stat: user_stat, count: -10, count_column: :post_count)

    expect(fake_logger.warnings.last).to match("post_count")
    expect(fake_logger.warnings.last).to match("using 0")
    expect(fake_logger.warnings.last).to match("user #{user_stat.user_id}")
    expect(user_stat.reload.post_count).to eq(0)
  end
end
