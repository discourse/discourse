# frozen_string_literal: true

RSpec.describe Jobs::BotInput do
  fab!(:user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:, user:) }

  let(:discobot_user) { DiscourseNarrativeBot::Base.new.discobot_user }

  before do
    discobot_user
    SiteSetting.discourse_narrative_bot_enabled = true
    post.update!(raw: "@discobot quote")
  end

  it "does nothing when the user no longer exists" do
    missing_user_id = User.maximum(:id).to_i + 100

    expect do
      described_class.new.execute(user_id: missing_user_id, post_id: post.id, input: "reply")
    end.to_not change { Post.count }
  end

  it "runs the track selector with the given input in the user's locale" do
    selector = mock
    selector.expects(:select).once
    DiscourseNarrativeBot::TrackSelector
      .expects(:new)
      .with(:reply, user, post_id: post.id, topic_id: nil)
      .returns(selector)

    described_class.new.execute(user_id: user.id, post_id: post.id, input: "reply")
  end

  it "replies to a quote request without contacting any external service" do
    expect do
      described_class.new.execute(user_id: user.id, post_id: post.id, input: "reply")
    end.to change { Post.count }.by(1)

    bundled_quotes =
      I18n
        .t("discourse_narrative_bot.quote")
        .values
        .select { |v| v.is_a?(Hash) }
        .map { |q| DiscourseNarrativeBot::QuoteGenerator.format_quote(q[:quote], q[:author]) }

    expect(Post.last.user).to eq(discobot_user)
    expect(bundled_quotes).to include(Post.last.raw)
  end

  it "propagates errors raised while processing a track" do
    DiscourseNarrativeBot::TrackSelector
      .any_instance
      .stubs(:select)
      .raises(StandardError.new("boom"))

    expect do
      described_class.new.execute(user_id: user.id, post_id: post.id, input: "reply")
    end.to raise_error(StandardError, "boom")
  end
end
