# frozen_string_literal: true

RSpec.describe "Delegated recurring Event editing" do
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:editor) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)

  let!(:source_post) do
    PostCreator.create!(
      author,
      title: "Shared wiki meeting",
      category: category.id,
      raw: "Original shared wiki notes.",
    )
  end

  let(:event_raw) do
    starts_at = 7.days.from_now.utc.change(sec: 0)
    ends_at = starts_at + 1.hour

    <<~RAW.chomp
      [event start="#{starts_at.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
      Shared meeting notes.
      [/event]
    RAW
  end

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_recurring_topic_mode = "create_next_topic"
    SiteSetting.edit_wiki_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
    SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

    expect(PostRevisor.new(source_post).revise!(author, { wiki: true }, bypass_bump: true)).to eq(
      true,
    )
  end

  def submit_edit(user, raw)
    sign_in(user)
    put "/posts/#{source_post.id}.json", params: { post: { raw: raw } }
  end

  it "allows a wiki editor to introduce a recurring Event" do
    expect(editor.guardian.can_edit_post?(source_post.reload)).to eq(true)
    expect(editor.guardian.can_create_discourse_post_event?).to eq(true)

    submit_edit(editor, event_raw)

    expect(response).to have_http_status(:ok)
    expect(source_post.reload.event.recurrence).to eq("every_week")
    expect(source_post.last_editor_id).to eq(editor.id)
    expect(source_post.user_id).to eq(author.id)
  end

  it "allows the author to enable recurrence on an editor's standalone Event" do
    standalone_raw = event_raw.sub(' recurrence="every_week"', "")

    submit_edit(editor, standalone_raw)
    expect(response).to have_http_status(:ok)
    expect(source_post.reload.event.recurrence).to be_nil

    submit_edit(author, event_raw)
    expect(response).to have_http_status(:ok)
    expect(source_post.reload.event.recurrence).to eq("every_week")
  end

  it "allows an authorised wiki editor to enable recurrence on an existing Event" do
    standalone_raw = event_raw.sub(' recurrence="every_week"', "")

    submit_edit(editor, standalone_raw)
    expect(response).to have_http_status(:ok)

    submit_edit(editor, event_raw)
    expect(response).to have_http_status(:ok)
    expect(source_post.reload.event.recurrence).to eq("every_week")
  end

  it "allows the original author to create recurrence" do
    submit_edit(author, event_raw)

    expect(response).to have_http_status(:ok)
    expect(source_post.reload.event.recurrence).to eq("every_week")
  end

  it "preserves delegated recurring Event creation under reuse_topic" do
    SiteSetting.discourse_post_event_recurring_topic_mode = "reuse_topic"

    submit_edit(editor, event_raw)

    expect(response).to have_http_status(:ok)
    expect(source_post.reload.event.recurrence).to eq("every_week")
  end

  it "notifies the original author of the editor and exact Event revision" do
    Jobs.run_immediately!
    PostActionNotifier.enable

    edited_type = Notification.types[:edited]

    expect { submit_edit(editor, event_raw) }.to change {
      author.notifications.where(notification_type: edited_type).count
    }.by(1)

    expect(response).to have_http_status(:ok)

    revision = source_post.reload.post_revisions.where(user_id: editor.id).order(:number).last

    expect(revision).to be_present

    raw_changes = revision.modifications.fetch("raw")
    expect(raw_changes.first).not_to include("[event")
    expect(raw_changes.last).to include('recurrence="every_week"')

    notification = author.notifications.where(notification_type: edited_type).order(:id).last

    expect(notification.topic_id).to eq(source_post.topic_id)
    expect(notification.post_number).to eq(1)
    expect(notification.read).to eq(false)

    data = JSON.parse(notification.data)
    expect(data.fetch("display_username")).to eq(editor.username)
    expect(data.fetch("revision_number")).to eq(revision.number)
    expect(author.guardian.can_view_edit_history?(source_post)).to eq(true)
  end
end
