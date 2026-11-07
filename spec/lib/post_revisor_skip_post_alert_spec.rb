# frozen_string_literal: true

RSpec.describe PostRevisor do
  fab!(:author, :user)
  fab!(:post) { Fabricate(:post, user: author, raw: "Original message") }

  def capture_post_alerts
    alerts = []

    allow(Jobs).to receive(:enqueue).and_wrap_original do |original, name, *args, **kwargs|
      options = kwargs.empty? ? args.first : kwargs

      if name == :post_alert && options.is_a?(Hash) && options[:post_id] == post.id
        alerts << options
      end

      original.call(name, *args, **kwargs)
    end

    alerts
  end

  def edit_post(**options)
    PostRevisor.new(post).revise!(
      author,
      { raw: "Updated message" },
      { bypass_bump: true, bypass_rate_limiter: true }.merge(options),
    )
  end

  it "enqueues a post alert for an ordinary edit" do
    alerts = capture_post_alerts

    expect(edit_post).to eq(true)
    expect(alerts).not_to be_empty
  end

  it "does not enqueue a post alert when explicitly suppressed" do
    alerts = capture_post_alerts

    expect(edit_post(skip_post_alert: true)).to eq(true)
    expect(alerts).to be_empty
  end
end
