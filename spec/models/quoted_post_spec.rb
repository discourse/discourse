# frozen_string_literal: true

require 'rails_helper'

describe QuotedPost do
  it 'correctly extracts quotes' do
    Jobs.run_immediately!

    topic = Fabricate(:topic)
    post1 = create_post(topic: topic, post_number: 1, raw: "foo bar")
    post2 = create_post(topic: topic, post_number: 2, raw: "lorem ipsum")
    post3 = create_post(topic: topic, post_number: 3, raw: "test post")

    raw = <<~RAW
      #{post1.full_url}

      [quote="#{post2.user.username}, post:#{post2.post_number}, topic:#{post2.topic.id}"]
      lorem
      [/quote]

      this is a test post

      #{post3.full_url}
    RAW

    post4 = create_post(topic: topic, raw: raw, post_number: 4, reply_to_post_number: post3.post_number)

    expect(QuotedPost.where(post_id: post4.id).pluck(:quoted_post_id)).to contain_exactly(post1.id, post2.id, post3.id)
    expect(post4.reload.reply_quoted).to eq(true)

    SiteSetting.editing_grace_period = 1.minute.to_i
    post5 = create_post(topic: topic, post_number: 5, raw: "post 5")
    raw = raw.sub(post3.full_url, post5.full_url)
    post4.revise(post4.user, { raw: raw }, revised_at: post4.updated_at + 2.minutes)
    expect(QuotedPost.where(post_id: post4.id).pluck(:quoted_post_id)).to contain_exactly(post1.id, post2.id, post5.id)
  end

  it "doesn't count quotes from the same post" do
    Jobs.run_immediately!

    topic = Fabricate(:topic)
    post = create_post(topic: topic, post_number: 1, raw: "foo bar")

    post.cooked = <<-HTML
      <aside class="quote" data-post="#{post.post_number}" data-topic="#{post.topic_id}">
        <div class="title">
          <div class="quote-controls"></div>
          <img width="20" height="20" src="/user_avatar/meta.discourse.org/techapj/20/3281.png" class="avatar">techAPJ:
        </div>
        <blockquote><p>When the user will v</p></blockquote>
      </aside>
    HTML
    post.save!

    QuotedPost.extract_from(post)
    expect(QuotedPost.where(post_id: post.id).count).to eq(0)
    expect(QuotedPost.where(quoted_post_id: post.id).count).to eq(0)
  end

  it 'correctly handles deltas' do
    post1 = Fabricate(:post)
    post2 = Fabricate(:post)

    post2.cooked = <<-HTML
      <aside class="quote" data-post="#{post1.post_number}" data-topic="#{post1.topic_id}">
        <div class="title">
          <div class="quote-controls"></div>
          <img width="20" height="20" src="/user_avatar/meta.discourse.org/techapj/20/3281.png" class="avatar">techAPJ:
        </div>
        <blockquote><p>When the user will v</p></blockquote>
      </aside>
    HTML

    QuotedPost.create!(post_id: post2.id, quoted_post_id: 999)
    quote = QuotedPost.create!(post_id: post2.id, quoted_post_id: post1.id)
    original_date = quote.created_at

    freeze_time 1.hour.from_now

    QuotedPost.extract_from(post2)
    expect(QuotedPost.where(post_id: post2.id).count).to eq(1)
    expect(QuotedPost.find_by(post_id: post2.id, quoted_post_id: post1.id)).not_to eq(nil)

    quote.reload

    expect(original_date).to eq_time(quote.created_at)

    expect(post2.reply_quoted).to eq(false)
  end
end
