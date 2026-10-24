# frozen_string_literal: true

RSpec.describe Jobs::UpdateUsername do
  fab!(:user)

  it "does not do anything if user_id is invalid" do
    events =
      DiscourseEvent.track_events do
        described_class.new.execute(
          user_id: -999,
          old_username: user.username,
          new_username: "somenewusername",
          avatar_template: user.avatar_template,
        )
      end

    expect(events).to eq([])
  end

  it "does not rewrite similar mentions when the old username contains a dot" do
    renamed_user = Fabricate(:user, username: "foo.bar")
    Fabricate(:user, username: "foo-bar")
    author = Fabricate(:user)
    topic = Fabricate(:topic, user: author)

    Jobs.run_immediately!
    UserActionManager.enable
    post = create_post(user: author, topic: topic, raw: "@foo.bar @foo-bar")

    described_class.new.execute(
      user_id: renamed_user.id,
      old_username: renamed_user.username,
      new_username: "newname",
      avatar_template: renamed_user.avatar_template,
    )

    post.reload

    expect(post.raw).to eq("@newname @foo-bar")
    expect(post.cooked).to match_html <<~HTML
      <p><a class="mention" href="/u/newname">@newname</a> <a class="mention" href="/u/foo-bar">@foo-bar</a></p>
    HTML
  end

  it "updates the category description when a category description topic mentions the user" do
    category = Fabricate(:category_with_definition, user: Discourse.system_user)
    first_post = category.topic.first_post
    first_post.revise(first_post.user, { raw: "This category is managed by @#{user.username}" })
    category.reload

    expect(category.description).to include(user.username)

    old_username = user.username
    new_username = "new_username_123"

    described_class.new.execute(
      user_id: user.id,
      old_username:,
      new_username:,
      avatar_template: user.avatar_template,
    )
    category.reload

    expect(category.description).to include(new_username)
    expect(category.description).not_to include(old_username)
  end

  it "rewrites omitted answers and cached originals without mention actions" do
    template =
      Fabricate(
        :form_template,
        template: [{ id: "note", type: "textarea" }].as_json.to_yaml,
        output_template: "A fixed invitation for the evening.",
      )
    original =
      FormTemplate::Submission.from_template(
        template,
        answers: {
          "note" => "Ask @#{user.username}",
        },
      )
    post = create_post(raw: original.render, form_data: original.to_h)
    changed = original.with_answers({ "note" => "Invite @#{user.username}" })
    PostRevisor.new(post).revise!(post.user, { raw: changed.render, form_data: changed.to_h })

    described_class.new.execute(
      user_id: user.id,
      old_username: user.username,
      new_username: "newname",
      avatar_template: user.avatar_template,
    )

    post.reload
    expect(post.form_submission.answers).to eq("note" => "Invite @newname")
    final = post.form_submission.with_answers({ "note" => "All invited" })
    PostRevisor.new(post).revise!(
      post.user,
      { raw: final.render, form_data: final.to_h },
      force_new_version: true,
    )
    expect(post.revisions.last.form_data_changes.first.dig("answers", "note")).to eq("Ask @newname")
  end

  it "leaves generated mentions and their form state unchanged when they cannot be rewritten together" do
    template =
      Fabricate(
        :form_template,
        template: [{ id: "username", type: "input" }].as_json.to_yaml,
        output_template: "An invitation for @{{ answers.username }}.",
      )
    submission =
      FormTemplate::Submission.from_template(template, answers: { "username" => user.username })
    post = create_post(raw: submission.render, form_data: submission.to_h)
    raw = post.raw
    cooked = post.cooked

    described_class.new.execute(
      user_id: user.id,
      old_username: user.username,
      new_username: "newname",
      avatar_template: user.avatar_template,
    )

    expect(post.reload.raw).to eq(raw)
    expect(post.cooked).to eq(cooked)
    expect(post.form_data).to eq(submission.to_h)
  end
end
