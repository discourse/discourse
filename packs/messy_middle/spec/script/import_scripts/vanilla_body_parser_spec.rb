# frozen_string_literal: true

require_relative "../../../../../script/import_scripts/vanilla_body_parser"
require_relative "../../../../../script/import_scripts/base/lookup_container"
require_relative "../../../../../script/import_scripts/base/uploader"

RSpec.describe VanillaBodyParser do
  let(:lookup) { ImportScripts::LookupContainer.new }
  let(:uploader) { ImportScripts::Uploader.new }
  let(:uploads_path) { "spec/fixtures/images/vanilla_import" }
  let(:user) do
    Fabricate(
      :user,
      email: "saruman@maiar.org",
      name: "Saruman, Multicolor",
      username: "saruman_multicolor",
    )
  end
  let(:user_id) { lookup.add_user(user.id.to_s, user) }

  before do
    STDOUT.stubs(:write)
    STDERR.stubs(:write)

    VanillaBodyParser.configure(
      lookup: lookup,
      uploader: uploader,
      host: "vanilla.sampleforum.org",
      uploads_path: uploads_path,
    )
  end

  it "keeps regular text intact" do
    parsed =
      VanillaBodyParser.new({ "Format" => "Html", "Body" => "Hello everyone!" }, user_id).parse
    expect(parsed).to eq "Hello everyone!"
  end

  it "keeps html tags" do
    parsed =
      VanillaBodyParser.new(
        { "Format" => "Html", "Body" => "H<br>E<br>L<br>L<br>O" },
        user_id,
      ).parse
    expect(parsed).to eq "H<br>E<br>L<br>L<br>O"
  end

  it "parses invalid html, removes font tags and leading spaces" do
    complex_html =
      "" \
        "<b><font color=green>this was bold and green:</b></font color=green>
    this starts with spaces but IS NOT a quote" \
        ""
    parsed = VanillaBodyParser.new({ "Format" => "Html", "Body" => complex_html }, user_id).parse
    expect(parsed).to eq "" \
         "<b>this was bold and green:</b>
this starts with spaces but IS NOT a quote" \
         ""
  end

  it "replaces pre tags with code backticks" do
    complex_html = '<pre class="CodeBlock">foobar</pre>'
    parsed = VanillaBodyParser.new({ "Format" => "Html", "Body" => complex_html }, user_id).parse
    expect(parsed).to eq "\n```\nfoobar\n```\n"
  end

  it "strips code tags" do
    complex_html = "<code>foobar</code>"
    parsed = VanillaBodyParser.new({ "Format" => "Html", "Body" => complex_html }, user_id).parse
    expect(parsed).to eq "foobar"
  end

  it "replaces div with quote class to bbcode quotes" do
    complex_html = '<div class="Quote">foobar</div>'
    parsed = VanillaBodyParser.new({ "Format" => "Html", "Body" => complex_html }, user_id).parse
    expect(parsed).to eq "\n\n[quote]\n\nfoobar\n\n[/quote]\n\n"
  end

  describe "rich format" do
    let(:rich_bodies) do
      JSON.parse(File.read("spec/fixtures/json/vanilla-rich-posts.json")).deep_symbolize_keys
    end

    it "extracts text-only bodies" do
      parsed =
        VanillaBodyParser.new(
          { "Format" => "Rich", "Body" => rich_bodies[:text].to_json },
          user_id,
        ).parse
      expect(parsed).to eq "This is a message.\n\nAnd a second line."
    end

    it "supports mentions of non-imported users" do
      parsed =
        VanillaBodyParser.new(
          { "Format" => "Rich", "Body" => rich_bodies[:mention].to_json },
          user_id,
        ).parse
      expect(parsed).to eq "@Gandalf The Grey, what do you think?"
    end

    it "supports mentions imported users" do
      mentioned =
        Fabricate(
          :user,
          email: "gandalf@maiar.com",
          name: "Gandalf The Grey",
          username: "gandalf_the_grey",
        )
      lookup.add_user(mentioned.id.to_s, mentioned)

      body = rich_bodies[:mention].to_json.gsub("666", mentioned.id.to_s)
      parsed = VanillaBodyParser.new({ "Format" => "Rich", "Body" => body }, user_id).parse
      expect(parsed).to eq "@gandalf_the_grey, what do you think?"
    end

    it "supports links" do
      parsed =
        VanillaBodyParser.new(
          { "Format" => "Rich", "Body" => rich_bodies[:links].to_json },
          user_id,
        ).parse
      expect(
        parsed,
      ).to eq "We can link to the <a href=\"https:\/\/www.discourse.org\/\">Discourse home page</a> and it works."
    end

    it "supports quotes without topic info when it cannot be found" do
      parsed =
        VanillaBodyParser.new(
          { "Format" => "Rich", "Body" => rich_bodies[:quote].to_json },
          user_id,
        ).parse
      expect(
        parsed,
      ).to eq "[quote]\n\nThis is the full<br \/>body<br \/>of the quoted discussion.<br \/>\n\n[/quote]\n\nWhen did this happen?"
    end

    it "supports quotes with user and topic info" do
      post =
        Fabricate(
          :post,
          user: user,
          id: "discussion#12345",
          raw: "This is the full\r\nbody\r\nof the quoted discussion.\r\n",
        )

      topic_id = lookup.add_topic(post)
      lookup.add_post("discussion#12345", post)

      body = rich_bodies[:quote].to_json.gsub("34567", user.id.to_s)
      parsed = VanillaBodyParser.new({ "Format" => "Rich", "Body" => body }, user_id).parse
      expect(
        parsed,
      ).to eq "[quote=\"#{user.username}, post: #{post.post_number}, topic: #{post.topic.id}\"]\n\nThis is the full<br \/>body<br \/>of the quoted discussion.<br \/>\n\n[/quote]\n\nWhen did this happen?"
    end

    it "supports uploaded images" do
      parsed =
        VanillaBodyParser.new(
          { "Format" => "Rich", "Body" => rich_bodies[:image].to_json },
          user_id,
        ).parse
      expect(parsed).to match(
        %r{Here's the screenshot\:\n\n\!\[Screen Shot 2020\-05\-26 at 7\.09\.06 AM\.png\|\d+x\d+\]\(upload\://\w+\.png\)$},
      )
    end

    it "supports embedded links" do
      parsed =
        VanillaBodyParser.new(
          { "Format" => "Rich", "Body" => rich_bodies[:embed_link].to_json },
          user_id,
        ).parse
      expect(
        parsed,
      ).to eq "Does anyone know this website?\n\n[Title of the page being linked](https:\/\/someurl.com\/long\/path\/here_and_there\/?fdkmlgm)"
    end

    it "keeps uploaded files as links" do
      parsed =
        VanillaBodyParser.new(
          { "Format" => "Rich", "Body" => rich_bodies[:upload_file].to_json },
          user_id,
        ).parse
      expect(
        parsed,
      ).to eq "This is a PDF I've uploaded:\n\n<a href=\"https://vanilla.sampleforum.org/uploads/393/5QR3BX57K7HM.pdf\">original_name_of_file.pdf</a>"
    end

    it "supports complex formatting" do
      parsed =
        VanillaBodyParser.new(
          { "Format" => "Rich", "Body" => rich_bodies[:complex_formatting].to_json },
          user_id,
        ).parse
      expect(
        parsed,
      ).to eq "<b>Name</b>: Jon Snow\n\n<b><i>* not their real name</i></b>\n\n<ol>\n\n<li>first item</li>\n\n<li>second</li>\n\n<li>third and last</li>\n\n</ol>\n\nThat's all folks!"
    end

    it "support code blocks" do
      parsed =
        VanillaBodyParser.new(
          { "Format" => "Rich", "Body" => rich_bodies[:code_block].to_json },
          user_id,
        ).parse
      expect(
        parsed,
      ).to eq "Here's a monospaced block:\n\n```\nthis line should be monospaced\nthis one too, with extra spaces#{" " * 4}\n```\n\nbut not this one"
    end
  end
end
