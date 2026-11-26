# frozen_string_literal: true

RSpec.describe "Digest emails for posts at Nokogiri's parser limits" do
  fab!(:reader) { Fabricate(:user, last_seen_at: 8.days.ago, last_emailed_at: 8.days.ago) }
  fab!(:member) { Fabricate(:user, trust_level: 1) }

  def create_topic(raw)
    sign_in(member)
    post "/posts.json", params: { raw: raw, title: "A perfectly ordinary topic title" }
    expect(response).to have_http_status(:ok)

    topic = Topic.find(response.parsed_body["topic_id"])
    # In production this is simply elapsed time.
    topic.update_columns(created_at: 1.hour.ago, bumped_at: 1.hour.ago)
    topic
  end

  def deliver_digest
    expect { Jobs::UserEmail.new.execute(type: :digest, user_id: reader.id) }.not_to raise_error
  end

  def nested_divs(depth)
    "<div>" * depth + "hello everybody" + "</div>" * depth
  end

  it "delivers the digest with a first post nested well within the parser limits" do
    topic = create_topic(nested_divs(300))

    deliver_digest

    expect(ActionMailer::Base.deliveries.map(&:to)).to contain_exactly([reader.email])
    expect(ActionMailer::Base.deliveries.last.html_part.body.to_s).to include(topic.title)
    expect(reader.user_stat.reload.digest_attempted_at).to be_present
  end

  it "delivers the digest with a first post at the tree depth limit" do
    topic = create_topic(nested_divs(399))

    deliver_digest

    expect(ActionMailer::Base.deliveries.map(&:to)).to contain_exactly([reader.email])
    expect(ActionMailer::Base.deliveries.last.html_part.body.to_s).to include(topic.title)
    expect(ActionMailer::Base.deliveries.last.text_part.body.to_s).to be_present
    expect(reader.user_stat.reload.digest_attempted_at).to be_present
    expect(Jobs::EnqueueDigestEmails.new.target_user_ids).not_to include(reader.id)
  end

  it "delivers the digest with a first post that only exceeds the limits once the email layout wraps it" do
    topic = create_topic(nested_divs(390))

    deliver_digest

    expect(ActionMailer::Base.deliveries.map(&:to)).to contain_exactly([reader.email])
    expect(ActionMailer::Base.deliveries.last.html_part.body.to_s).to include(topic.title)
    expect(reader.user_stat.reload.digest_attempted_at).to be_present
  end

  it "delivers the digest with a first post at the attribute limit" do
    attributes = (1..399).map { |i| "data-a#{i}" }.join(" ")
    topic = create_topic(%(<aside class="quote" #{attributes}>hello everybody</aside>))

    deliver_digest

    expect(ActionMailer::Base.deliveries.map(&:to)).to contain_exactly([reader.email])
    expect(ActionMailer::Base.deliveries.last.html_part.body.to_s).to include(topic.title)
    expect(reader.user_stat.reload.digest_attempted_at).to be_present
  end
end
