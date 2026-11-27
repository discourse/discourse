# frozen_string_literal: true

RSpec.describe "Digest emails for posts at Nokogiri's parser limits", type: :request do
  fab!(:reader) { Fabricate(:user, last_seen_at: 8.days.ago, last_emailed_at: 8.days.ago) }
  fab!(:member) { Fabricate(:user, trust_level: 1) }

  it "delivers the digest with a first post at the tree depth limit" do
    sign_in(member)
    post "/posts.json",
         params: {
           raw: "<div>" * 399 + "hello everybody" + "</div>" * 399,
           title: "A perfectly ordinary topic title",
         }
    expect(response).to have_http_status(:ok)

    topic = Topic.find(response.parsed_body["topic_id"])
    # In production this is simply elapsed time.
    topic.update_columns(created_at: 1.hour.ago, bumped_at: 1.hour.ago)

    expect { Jobs::UserEmail.new.execute(type: :digest, user_id: reader.id) }.not_to raise_error

    expect(ActionMailer::Base.deliveries.map(&:to)).to contain_exactly([reader.email])
    expect(ActionMailer::Base.deliveries.last.html_part.body.to_s).to include(topic.title)
    expect(ActionMailer::Base.deliveries.last.text_part.body.to_s).to be_present
    expect(reader.user_stat.reload.digest_attempted_at).to be_present
    expect(Jobs::EnqueueDigestEmails.new.target_user_ids).not_to include(reader.id)
  end
end
