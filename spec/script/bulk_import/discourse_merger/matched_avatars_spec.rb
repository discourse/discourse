# frozen_string_literal: true

require_relative "../../../../script/bulk_import/discourse_merger/support"

RSpec.describe BulkImport::DiscourseMerge::MatchedAvatars do
  let(:matches) { [8, 7].map { |id| { "source_user_id" => id, "destination_user_id" => 27 } } }
  let(:sources) do
    {
      8 => {
        "id" => "8",
        "username" => "Other",
        "public_avatar_id" => "4",
      },
      7 => {
        "id" => "7",
        "username" => "Old",
        "public_avatar_id" => "3",
      },
    }
  end
  let(:destination) { { 27 => { "username" => "Merged", "uploaded_avatar_id" => nil } } }
  let(:decisions) { described_class.decisions(matches, sources, destination) }
  let(:uploads) { { 3 => 103, 4 => 104 } }

  it "retains a destination upload even when a source upload is available" do
    destination[27]["uploaded_avatar_id"] = "70"
    expect(decisions.first).to include("choice" => "destination", "upload_id" => 70)
    expect(described_class.destination_upload(decisions.first, uploads)).to eq(70)
  end

  it "adopts the eligible selected upload of the lowest source ID" do
    expect(decisions.first).to include("choice" => "source", "upload_id" => 3)
    expect(described_class.destination_upload(decisions.first, uploads)).to eq(103)
    sources[7]["public_avatar_id"] = nil
    expect(described_class.decisions(matches, sources, destination).first.fetch("upload_id")).to eq(
      4,
    )
  end

  it "keeps the destination default when neither member supplies a public image" do
    sources.each_value { |row| row["public_avatar_id"] = nil }
    expect(decisions.first).to include("choice" => "default", "upload_id" => nil)
  end

  it "uses the configured destination default at the requested size" do
    sources.each_value { |row| row["public_avatar_id"] = nil }
    users = class_double("User").as_stubbed_const
    allow(users).to receive(:default_template).with("Merged").and_return(
      "//images.example/default/{size}.png",
    )
    references =
      BulkImport::DiscourseMerge::References.new(
        source_host: "incoming.example",
        destination_host: "hosted.example",
        topics: {
        },
        categories: {
        },
        matched_avatars: decisions,
        upload_mode: "preuploaded",
      )
    expect(references.rewrite("/user_avatar/incoming.example/Old/40/999.png")).to eq(
      "https://images.example/default/40.png",
    )
  end

  it "uses the mapped upload for a new account whose username collides with a matched destination name" do
    stub_const("OptimizedImage::VERSION", 5)
    references =
      BulkImport::DiscourseMerge::References.new(
        source_host: "incoming.example",
        destination_host: "hosted.example",
        topics: {
        },
        categories: {
        },
        matched_avatars: decisions,
        usernames: {
          "Merged" => "Merged_1",
        },
        uploads: uploads,
        upload_mode: "preuploaded",
      )
    expect(references.rewrite("/user_avatar/incoming.example/Merged/40/4.png")).to eq(
      "https://hosted.example/user_avatar/hosted.example/Merged_1/40/104_5.png",
    )
  end

  it "rewrites embedded letters using the adjacent source member and preserves unidentified letters" do
    stub_const("OptimizedImage::VERSION", 5)
    refs =
      BulkImport::DiscourseMerge::References.new(
        source_host: "incoming.example",
        destination_host: "hosted.example",
        topics: {
        },
        categories: {
        },
        matched_avatars: decisions,
        uploads: uploads,
        usernames: {
          "Old" => "Merged",
        },
      )
    letter = "/letter_avatar_proxy/v4/letter/o/ababab/50.png"
    photo = "https://hosted.example/user_avatar/hosted.example/merged/50/103_5.png"
    raw = "![avatar|25x25](#{letter}) @Old"
    expect(refs.rewrite(raw)).to eq("![avatar|25x25](#{photo}) @Merged")
    expect(refs.rewrite("[![avatar](#{letter})](/u/old)")).to eq(
      "[![avatar](#{photo})](https://hosted.example/u/Merged)",
    )
    wrapped = %(<a href="/u/old"><img src="#{letter}" srcset="#{letter} 2x"></a>)
    expect(refs.rewrite(wrapped, cooked: true)).to eq(
      %(<a href="https://hosted.example/u/Merged"><img src="#{photo}"></a>),
    )
    srcset_first = %(<a href="/u/old"><img srcset="#{letter} 2x" src="#{letter}"></a>)
    expect(refs.rewrite(srcset_first, cooked: true)).to eq(
      %(<a href="https://hosted.example/u/Merged"><img src="#{photo}"></a>),
    )
    expect(refs.rewrite("`#{raw}`")).to eq("`#{raw}`")
    foreign = "![avatar](https://unrelated.example#{letter})"
    expect(refs.rewrite(foreign)).to eq(foreign)
    expect(refs.rewrite("![avatar](#{letter})")).to eq(
      "![avatar](https://avatars.discourse-cdn.com/v4/letter/o/ababab/50.png)",
    )
    html = %(<img src="#{letter}" width="25"> <a href="/u/old">@Old</a>)
    expect(refs.rewrite(html, cooked: true)).to eq(
      %(<img src="#{photo}" width="25"> <a href="https://hosted.example/u/Merged">@Merged</a>),
    )
  end

  it "resolves a member avatar once when the two forums share an origin" do
    stub_const("OptimizedImage::VERSION", 5)
    refs =
      BulkImport::DiscourseMerge::References.new(
        source_host: "same.example",
        destination_host: "same.example",
        topics: {
        },
        categories: {
        },
        matched_avatars: decisions,
        uploads: uploads,
        usernames: {
          "Old" => "Merged",
        },
        upload_mode: "preuploaded",
      )
    image = "/letter_avatar_proxy/v4/letter/o/ababab/50.png"
    result = "https://same.example/user_avatar/same.example/merged/50/103_5.png"
    raw = "![avatar|25x25](#{image}) @Old"
    expect(refs.rewrite(raw)).to eq("![avatar|25x25](#{result}) @Merged")
    html = %(<img src="#{image}"> <a href="/u/old">@Old</a>)
    expect(refs.rewrite(html, cooked: true)).to eq(
      %(<img src="#{result}"> <a href="https://same.example/u/Merged">@Merged</a>),
    )
    expect(refs.rewrite("/user_avatar/same.example/Old/50/3.png")).to eq(result)
  end

  it "uses the same destination default for historical uploaded and letter images" do
    sources.each_value { |row| row["public_avatar_id"] = nil }
    users = class_double("User").as_stubbed_const
    allow(users).to receive(:default_template).with("Merged").and_return(
      "/letter_avatar_proxy/v4/letter/m/ffffff/{size}.png",
    )
    stub_const("Discourse", Module.new) unless defined?(Discourse)
    allow(Discourse).to receive(:base_path).and_return("")
    refs =
      BulkImport::DiscourseMerge::References.new(
        source_host: "source.example",
        destination_host: "dest.example",
        topics: {
        },
        categories: {
        },
        matched_avatars: decisions,
      )
    final = "https://avatars.discourse-cdn.com/v4/letter/m/ffffff/50.png"
    expect(
      refs.rewrite("![avatar](/letter_avatar_proxy/v4/letter/o/aaaaaa/50.png) @Old"),
    ).to include(final)
    expect(refs.rewrite("/user_avatar/source.example/Old/50/3.png")).to eq(final)
  end

  it "rewrites renamed members' historical avatar links in all storage modes" do
    stub_const("OptimizedImage::VERSION", 5)
    link = "https://incoming.example/user_avatar/incoming.example/Old/50/999_1.png"
    cdn = "//cdn.example/avatars/8/50/999_1.png"
    image = "https://hosted.example/user_avatar/hosted.example/merged/50/103_5.png"
    %w[copy preserve_remote preuploaded].each do |mode|
      references =
        BulkImport::DiscourseMerge::References.new(
          source_host: "incoming.example",
          destination_host: "hosted.example",
          topics: {
          },
          categories: {
          },
          matched_avatars: decisions,
          uploads: uploads,
          upload_mode: mode,
          media_origins: {
            "cdn_url" => "https://cdn.example",
          },
        )
      expect(references.rewrite("![pic](#{link})")).to eq("![pic](#{image})")
      expect(references.rewrite(%(<img src="#{cdn}">), cooked: true)).to eq(%(<img src="#{image}">))
      expect(references.rewrite("upload://regular")).to eq("upload://regular")
      expect(references.rewrite("`#{link}`")).to eq("`#{link}`")
      expect(references.rewrite(link.sub("https://incoming.", "https://unrelated."))).to start_with(
        "https://unrelated.",
      )
    end
  end
end
