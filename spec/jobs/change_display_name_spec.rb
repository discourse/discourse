# frozen_string_literal: true

RSpec.describe Jobs::ChangeDisplayName do
  before { stub_image_size }

  let(:username) { "codinghorror" }
  let(:old_display_name) { "|| Jeff ||" }
  let(:new_display_name) { "|| Mr. Atwood ||" }

  let(:user) { Fabricate(:user, username: username, name: old_display_name) }
  let(:topic) { Fabricate(:topic, user: user) }
  let!(:post) { create_post(post_attributes.merge(topic_id: topic.id)) }

  let!(:quoted_post) { create_post(user: user, topic: topic, post_number: 1, raw: "quoted post") }
  let(:avatar_url) { user.avatar_template_url.gsub("{size}", "48") }

  let(:post_attributes) { { raw: <<~RAW } }
    [quote="#{old_display_name}, post:1, topic:#{quoted_post.topic.id}, username:#{username}"]
    quoted post
    [/quote]
  RAW

  let(:revised_post_attributes) { { raw: <<~RAW } }
    [quote="#{old_display_name}, post:1, topic:#{quoted_post.topic.id}, username:#{username}"]
    quoted post
    [/quote]
    Forgot something.
  RAW

  let(:args) { { user_id: user.id, old_name: old_display_name, new_name: new_display_name } }

  describe "#execute" do
    context "when the renamed user has been quoted" do
      it "rewrites the raw quote display name" do
        expect { described_class.new.execute(args) }.to change { post.reload.raw }.to(<<~RAW.strip)
          [quote="#{new_display_name}, post:1, topic:#{quoted_post.topic.id}, username:#{username}"]
          quoted post
          [/quote]
        RAW
      end

      it "rewrites the cooked quote display name" do
        expect { described_class.new.execute(args) }.to change { post.reload.cooked }.to(
          match_html(<<~HTML.strip),
          <aside class="quote no-group" data-username="#{username}" data-post="1" data-topic="#{quoted_post.topic.id}">
          <div class="title">
          <div class="quote-controls"></div>
          <img alt="" width="24" height="24" src="#{avatar_url}" class="avatar"> #{new_display_name}:</div>
          <blockquote>
          <p>quoted post</p>
          </blockquote>
          </aside>
        HTML
        )
      end
    end

    context "when the user has been quoted in revisions" do
      before { post.revise(post.user, revised_post_attributes, force_new_version: true) }

      it "rewrites the quote in revisions" do
        expect { described_class.new.execute(args) }.to change {
          post.reload.revisions[0].modifications["raw"][0]
        }.to(<<~RAW.strip)
          [quote="#{new_display_name}, post:1, topic:#{quoted_post.topic.id}, username:#{username}"]
          quoted post
          [/quote]
          RAW
      end
    end
  end
end
