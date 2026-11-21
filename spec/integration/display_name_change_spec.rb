# frozen_string_literal: true

RSpec.describe "Display name change in quotes" do
  subject(:change_names) do
    sign_in(quoted_user)
    names.each { put "/u/#{quoted_user.username}.json", params: { name: it } }
  end

  fab!(:quoted_user) { Fabricate(:user, username: "bob", name: "Bob", refresh_auto_groups: true) }
  fab!(:quoting_user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:quoted_post) { create_post(user: quoted_user, raw: "Item, with a username.") }
  let(:tag_attributes) { "post:#{quoted_post.post_number}, topic:#{quoted_post.topic_id}" }
  let!(:quoting_post) do
    create_post(user: quoting_user, topic_id: quoted_post.topic_id, raw: <<~RAW)
      [quote="#{attribution}"]
      Item, with a username.
      [/quote]

      Done.
    RAW
  end

  before do
    Jobs.run_immediately!
    stub_image_size
  end

  context "when the quote is attributed to the username" do
    let(:attribution) { "bob, #{tag_attributes}" }
    let(:names) { [%(bob, #{tag_attributes}"]\nItem), "Text"] }

    it "does not change the quoting post" do
      expect { change_names }.not_to change { quoting_post.reload.raw }
    end
  end

  context "when the quote is attributed to the display name" do
    let(:attribution) { "Bob, #{tag_attributes}, username:bob" }

    before do
      SiteSetting.display_name_on_posts = true
      SiteSetting.prioritize_username_in_ux = false
    end

    context "with a display name that has quotation marks and line breaks" do
      let(:names) { [%(Bob"]\n\nText\n\n[quote="Bob)] }

      it "keeps the new display name in the quote tag" do
        expect { change_names }.to change { quoting_post.reload.raw.lines.first }.to(
          %([quote="Bob] Text [quote=Bob, #{tag_attributes}, username:bob"]\n),
        )
      end
    end

    context "with a plain display name" do
      let(:names) { ["Bob Smith"] }

      it "rewrites the display name in the quote tag" do
        expect { change_names }.to change { quoting_post.reload.raw.lines.first }.to(
          %([quote="Bob Smith, #{tag_attributes}, username:bob"]\n),
        )
      end
    end
  end
end
