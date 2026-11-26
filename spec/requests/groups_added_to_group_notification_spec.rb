# frozen_string_literal: true

describe "Added to group system messages" do
  fab!(:owner) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:recipient) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:group) { Fabricate(:group, name: "book_club") }

  let(:markdown_full_name) do
    "Staff](https://phish.example/verify) team. **Verify your account now** or lose access. [Staff"
  end

  before do
    group.add_owner(owner)
    Jobs.run_immediately!
    sign_in(owner)
  end

  def update_full_name(full_name)
    put "/groups/#{group.id}.json", params: { group: { full_name: full_name } }
    expect(response.status).to eq(200)
  end

  def add_member(username, path: "members")
    put "/groups/#{group.id}/#{path}.json", params: { usernames: username, notify_users: true }
    expect(response.status).to eq(200)
  end

  def last_system_message_for(user)
    topic =
      Topic
        .private_messages
        .where(subtype: TopicSubtype.system_message)
        .joins(:allowed_users)
        .where(topic_allowed_users: { user_id: user.id })
        .order(:id)
        .last
    topic.posts.order(:post_number).first
  end

  it "renders an owner-provided full name as text instead of markup" do
    update_full_name(markdown_full_name)
    add_member(recipient.username)

    post = last_system_message_for(recipient)
    expect(post.user).to eq(Discourse.system_user)

    sign_in(recipient)
    get "/t/#{post.topic_id}.json"
    expect(response.status).to eq(200)

    cooked = Nokogiri::HTML5.fragment(response.parsed_body["post_stream"]["posts"].first["cooked"])
    anchors = cooked.css("a")

    expect(anchors.map { |anchor| anchor["href"] }).to eq(["//test.localhost/g/book_club"])
    expect(anchors.first.text).to eq(markdown_full_name)
    expect(cooked.css("strong")).to be_empty
  end

  it "keeps the plain full name in the subject" do
    update_full_name(markdown_full_name)
    add_member(recipient.username)

    post = last_system_message_for(recipient)

    expect(post.topic.title).to eq(
      I18n.t(
        "system_messages.user_added_to_group_as_member.subject_template",
        group_name: markdown_full_name,
      ),
    )
  end

  it "does not render markup from a full name with newlines" do
    stub_request(:get, "https://phish.example/p.png").to_return(
      status: 200,
      body: "",
      headers: {
        "Content-Type" => "image/png",
      },
    )
    update_full_name("x](#)\n\n# Security notice\n\n![](https://phish.example/p.png) [y")
    add_member(recipient.username)

    cooked = last_system_message_for(recipient).cooked

    expect(cooked).not_to include("<h1")
    expect(cooked).not_to include("<img")
  end

  it "does not render the full name markup in notification emails" do
    update_full_name(markdown_full_name)
    add_member(recipient.username)

    post = last_system_message_for(recipient)
    mail =
      UserNotifications.user_private_message(
        recipient,
        post: post,
        notification_type: "private_message",
        notification_data_hash: {
          original_username: Discourse.system_user.username,
          topic_title: post.topic.title,
        },
      )

    html = Nokogiri::HTML5.fragment(mail.html_part.body.decoded)
    expect(html.css("a[href]").map { |anchor| anchor["href"] }.grep(/phish\.example/)).to be_empty
    expect(html.text).to include(markdown_full_name)
  end

  it "renders an owner-provided full name as text in the owner message" do
    update_full_name(markdown_full_name)
    add_member(recipient.username, path: "owners")

    cooked = Nokogiri::HTML5.fragment(last_system_message_for(recipient).cooked)

    expect(cooked.css("a").map { |anchor| anchor["href"] }).to eq(["//test.localhost/g/book_club"])
    expect(cooked.css("strong")).to be_empty
  end
end
