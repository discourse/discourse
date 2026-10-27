# frozen_string_literal: true

require "rails_helper"

RSpec.describe Live::OneboxHandler do
  fab!(:room) do
    Fabricate(
      :live_room,
      name: "Watercooler",
      description: "Drop in & **chat** <script>alert(1)</script>",
      public: true,
    )
  end
  fab!(:stage_room) do
    Fabricate(:live_room, name: "Town Hall", public: true, room_type: Live::Room::ROOM_TYPE_STAGE)
  end
  fab!(:private_room) { Fabricate(:live_room, name: "Secret Sessions") }
  fab!(:ephemeral_room) { Fabricate(:live_ephemeral_room, name: "Call", public: true) }

  before { SiteSetting.live_enabled = true }

  def room_url(room, suffix = "")
    "#{Discourse.base_url}/live/r/#{room.slug}#{suffix}"
  end

  def preview(url)
    Nokogiri::HTML5.fragment(Oneboxer.preview(url, invalidate_oneboxes: true))
  end

  it "renders a card for a public room" do
    html = preview(room_url(room))

    expect(html.at_css(".live-room-onebox__title a")["href"]).to eq(room_url(room))
    expect(html.at_css(".live-room-onebox__name").text).to eq("Watercooler")
    expect(html.at_css(".live-room-onebox__title use")["href"]).to eq("#microphone-lines")
    expect(html.at_css(".live-room-onebox__type").text).to eq(I18n.t("live.onebox.room_type.open"))
    expect(html.at_css(".live-room-onebox__description").text).to eq("Drop in & chat")
    expect(html.at_css("script")).to be_nil
  end

  it "escapes markup in the room name and description" do
    room.update!(
      name: "<img src=x onerror=alert(1)>",
      description: "`<img src=x onerror=alert(2)>` and &lt;b&gt;bold&lt;/b&gt;",
    )

    html = preview(room_url(room))

    expect(html.at_css(".live-room-onebox__name").text).to eq("<img src=x onerror=alert(1)>")
    expect(html.at_css(".live-room-onebox__description").text).to eq(
      "<img src=x onerror=alert(2)> and <b>bold</b>",
    )
    expect(html.css("img, b")).to be_empty
  end

  it "omits the description when the room has none" do
    html = preview(room_url(stage_room))

    expect(html.at_css(".live-room-onebox__title use")["href"]).to eq("#podcast")
    expect(html.at_css(".live-room-onebox__type").text).to eq(I18n.t("live.onebox.room_type.stage"))
    expect(html.at_css(".live-room-onebox__description")).to be_nil
  end

  it "renders a card for an invite link" do
    url = room_url(room, "/invited-by/#{Fabricate(:user).username}")

    expect(preview(url).at_css(".live-room-onebox__title a")["href"]).to eq(url)
  end

  it "falls back to a plain link for a room an anonymous visitor cannot see" do
    [private_room, ephemeral_room].each do |hidden_room|
      expect(preview(room_url(hidden_room)).at_css(".live-room-onebox")).to be_nil
    end

    expect(preview("#{Discourse.base_url}/live/r/missing").at_css(".live-room-onebox")).to be_nil
  end

  it "falls back to a plain link when Live is closed to anonymous visitors" do
    SiteSetting.live_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

    expect(preview(room_url(room)).at_css(".live-room-onebox")).to be_nil
  end

  it "falls back to a plain link when Live is disabled" do
    SiteSetting.live_enabled = false

    expect(preview(room_url(room)).at_css(".live-room-onebox")).to be_nil
  end

  describe "inline oneboxes" do
    it "titles a public room link with the room name and an icon class" do
      onebox = InlineOneboxer.lookup(room_url(room), skip_cache: true)

      expect(onebox).to eq(
        url: room_url(room),
        title: I18n.t("live.onebox.inline_to_room", room_name: "Watercooler"),
        css_class: "live-inline-onebox-room",
      )
    end

    it "uses the stage icon class for stage rooms" do
      onebox = InlineOneboxer.lookup(room_url(stage_room), skip_cache: true)

      expect(onebox[:css_class]).to eq("live-inline-onebox-stage")
    end

    it "leaves links to hidden rooms alone" do
      expect(InlineOneboxer.lookup(room_url(private_room), skip_cache: true)).to be_nil
    end
  end

  describe "chat messages", if: defined?(::Chat) do
    before { SiteSetting.chat_enabled = true }

    it "renders a card and an inline onebox" do
      message =
        Fabricate(
          :chat_message,
          message: "#{room_url(room)}\n\nJoin us in #{room_url(stage_room)} later",
        )

      processor = Chat::MessageProcessor.new(message, invalidate_oneboxes: true)
      processor.run!
      html = Nokogiri::HTML5.fragment(processor.html)

      expect(html.at_css(".live-room-onebox .live-room-onebox__name").text).to eq("Watercooler")
      expect(html.at_css("a.inline-onebox.live-inline-onebox-stage").text).to eq(
        I18n.t("live.onebox.inline_to_room", room_name: "Town Hall"),
      )
    end
  end
end
