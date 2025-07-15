# frozen_string_literal: true

describe "discourse_post_event_allowed_custom_fields" do
  let(:user_1) { Fabricate(:user, admin: true) }
  let(:topic_1) { Fabricate(:topic, user: user_1) }
  let(:post_1) { Fabricate(:post, topic: topic_1) }
  let(:post_event_1) { Fabricate(:event, post: post_1) }

  before do
    SiteSetting.discourse_post_event_allowed_custom_fields = "foo|bar|foo-bar|foo_baz"
    post_event_1.update!(custom_fields: {})

    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    Jobs.run_immediately!
  end

  it "removes the key on the custom fields when removing a key from site setting" do
    post_event_1.update!(custom_fields: { foo: 1, bar: 2 })

    expect(post_event_1.custom_fields["foo"]).to eq(1)
    expect(post_event_1.custom_fields["bar"]).to eq(2)

    DiscourseEvent.trigger(
      :site_setting_changed,
      :discourse_post_event_allowed_custom_fields,
      "foo|bar",
      "foo",
    )

    post_event_1.reload

    expect(post_event_1.custom_fields["foo"]).to eq(1)
    expect(post_event_1.custom_fields["bar"]).to eq(nil)
  end

  it "doesn’t set a not allowed key from site setting" do
    expect { post_event_1.update!(custom_fields: { baz: 3 }) }.to raise_error(
      ActiveRecord::RecordInvalid,
    )
  end

  it "works with a setting containing dash" do
    post = create_post_with_event(user_1, "fooBar='1'")
    expect(post.event.custom_fields["foo-bar"]).to eq("1")
    expect(post.event.custom_fields["foo_bar"]).to eq(nil)
    expect(post.event.custom_fields["fooBar"]).to eq(nil)
  end

  it "works with a setting containing underscore" do
    post = create_post_with_event(user_1, "fooBaz='1'")
    expect(post.event.custom_fields["foo_baz"]).to eq("1")
    expect(post.event.custom_fields["foo-baz"]).to eq(nil)
    expect(post.event.custom_fields["fooBaz"]).to eq(nil)
  end
end
