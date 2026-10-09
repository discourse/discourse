# frozen_string_literal: true
RSpec.describe ReviewableNoteSerializer do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:reviewable, :reviewable_flagged_post)
  fab!(:note) do
    Fabricate(:reviewable_note, reviewable: reviewable, user: admin, content: "Test note content")
  end
  def serialized_note(note, current_user = admin)
    ReviewableNoteSerializer.new(note, scope: Guardian.new(current_user), root: false).as_json
  end
  describe "serialization" do
    let(:json) { serialized_note(note) }

    it "includes basic attributes" do
      expect(json[:id]).to eq(note.id)
      expect(json[:content]).to eq("Test note content")
      expect(json[:created_at]).to be_present
      expect(json[:updated_at]).to be_present
    end

    it "includes user information" do
      expect(json[:user]).to be_present
      expect(json[:user][:id]).to eq(admin.id)
      expect(json[:user][:username]).to eq(admin.username)
    end

    it "renders mentions as user profile links, including in existing notes" do
      SiteSetting.enable_mentions = true
      note.update!(content: "Please ask @#{user.username} for help.")

      cooked = Nokogiri::HTML5.fragment(serialized_note(note.reload)[:cooked])
      mention = cooked.at_css("a.mention")

      expect(mention["href"]).to eq("/u/#{user.username_lower}")
      expect(mention.text).to eq("@#{user.username}")
    end

    it "preserves HTML and Markdown as literal text" do
      note.update!(content: '<script>alert(1)</script><img src="x" onerror="alert(2)">')

      cooked = Nokogiri::HTML5.fragment(serialized_note(note)[:cooked])

      expect(cooked.css("script, [onerror]")).to be_empty
      expect(cooked.text).to eq(note.content)

      note.update_columns(
        content:
          "  **bold** _italic_\n\n![image](https://example.com/image.png)\nhttps://example.com <b>HTML</b> & \"quotes\"",
      )

      cooked = Nokogiri::HTML5.fragment(serialized_note(note)[:cooked])

      expect(cooked.children.map(&:name)).to eq(["p"])
      expect(cooked.at_css("p").children.map(&:name)).to eq(["text"])
      expect(cooked.text).to eq(note.content)
    end

    it "preserves plaintext around mentions, including literal code and quotes" do
      SiteSetting.enable_mentions = true
      note.update_columns(
        content:
          "**Ask** @#{user.username}\n\n`@#{user.username}` > @#{user.username}\n<img src=x> & https://example.com",
      )

      cooked = Nokogiri::HTML5.fragment(serialized_note(note)[:cooked])

      expect(cooked.text).to eq(note.content)
      expect(cooked.css("a.mention").map(&:text)).to eq(["@#{user.username}"] * 3)
      expect(cooked.css("img, strong, code, blockquote")).to be_empty
    end

    it "links case-insensitive usernames with punctuation and the site base path" do
      SiteSetting.enable_mentions = true
      Discourse.stubs(:base_path).returns("/forum")
      note.update_columns(content: "(@#{user.username.upcase}), @#{user.username}.")

      cooked = Nokogiri::HTML5.fragment(serialized_note(note)[:cooked])

      expect(cooked.text).to eq(note.content)
      expect(cooked.css("a.mention").map { |mention| mention["href"] }).to eq(
        ["/forum/u/#{user.username_lower}"] * 2,
      )
    end

    it "keeps email addresses, unknown users, and groups literal" do
      SiteSetting.enable_mentions = true
      group = Fabricate(:group)
      note.update_columns(content: "person@#{user.username}.com @nonexistent_user @#{group.name}")

      cooked = Nokogiri::HTML5.fragment(serialized_note(note)[:cooked])

      expect(cooked.text).to eq(note.content)
      expect(cooked.css("a")).to be_empty
    end

    it "links Unicode usernames when enabled" do
      SiteSetting.enable_mentions = true
      SiteSetting.unicode_usernames = true
      unicode_user = Fabricate(:user, username: "élève")
      note.update_columns(content: "Ask @#{unicode_user.username}")

      cooked = Nokogiri::HTML5.fragment(serialized_note(note)[:cooked])

      expect(cooked.text).to eq(note.content)
      expect(cooked.at_css("a.mention")["href"]).to eq(
        "/u/#{UrlHelper.encode_component(unicode_user.username_lower)}",
      )
    end

    it "preserves mentions as literal text when mentions are disabled" do
      SiteSetting.enable_mentions = false
      note.update_columns(content: "Ask @#{user.username} <b>here</b>")

      cooked = Nokogiri::HTML5.fragment(serialized_note(note)[:cooked])

      expect(cooked.text).to eq(note.content)
      expect(cooked.css("a, b")).to be_empty
    end
  end
end
