# frozen_string_literal: true

RSpec.describe PrettyText do
  it "allows quoting chained messages" do
    cooked = PrettyText.cook <<~MD
    [chat quote="jan;101;2023-12-01T21:10:53Z" channel="Tech Talks" channelId="5" multiQuote="true" chained="true"]
    message 1
    [/chat]

    [chat quote="Kai;102;2023-12-01T21:10:53Z" chained="true"]
    message 2

    message 3
    [/chat]
    MD

    expect(cooked).to include('class="chat-transcript chat-transcript-chained"')
    expect(cooked).to include('data-channel-name="Tech Talks"')
    expect(cooked).to include('data-channel-id="5"')
  end

  it "allows quoting non-chained messages" do
    cooked = PrettyText.cook <<~MD
    [chat quote="jan;101;2023-12-01T21:10:53Z" channel="Tech Talks" channelId="5"]
    message 1
    [/chat]

    [chat quote="Kai;102;2023-12-01T21:10:53Z"]
    message 2

    message 3
    [/chat]
    MD

    expect(cooked).to include('class="chat-transcript"')
    expect(cooked).to include('data-channel-name="Tech Talks"')
    expect(cooked).to include('data-channel-id="5"')
    expect(cooked).not_to include("chat-transcript-chained")
  end

  it "includes channel metadata" do
    cooked = PrettyText.cook <<~MD
    [chat quote="alice;103;2023-12-02T10:20:30Z" channel="Game Grove" channelId="5" multiQuote="true"]
    message
    [/chat]
    MD

    expect(cooked).to include(
      "<div class=\"chat-transcript-meta\">\nOriginally sent in <a href=\"/chat/c/-/5\">Game Grove</a></div>",
    )
  end

  it "includes message reactions" do
    cooked = PrettyText.cook <<~MD
    [chat quote="alice;103;2023-12-02T10:20:30Z" reactions="smile:alice,bob;heart:carol"]
    This is a test message with reactions
    [/chat]
    MD

    expect(cooked).to include(
      "<div class=\"chat-transcript-reaction\">\n<img width=\"20\" height=\"20\" src=\"/images/emoji/twitter/heart.png?v=#{Emoji::EMOJI_VERSION}\" title=\"heart\" loading=\"lazy\" alt=\"heart\" class=\"emoji\"> 1</div>",
    )
    expect(cooked).to include(
      "<div class=\"chat-transcript-reaction\">\n<img width=\"20\" height=\"20\" src=\"/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}\" title=\"smile\" loading=\"lazy\" alt=\"smile\" class=\"emoji\"> 2</div>",
    )
  end

  it "allows quoting threads" do
    cooked = PrettyText.cook <<~MD
    [chat quote="jan;274;2023-12-06T04:15:00Z" channelId="2" threadId="140"]
    original message

    [chat quote="kai;274;2023-12-06T04:30:04Z" chained="true"]
    thread reply 1
    [/chat]

    [chat quote="jan;274;2023-12-06T05:00:00Z" chained="true"]
    thread reply 2
    [/chat]

    [/chat]
    MD
    expect(cooked).to include('class="chat-transcript-thread"')
    expect(cooked).to include("details")
    expect(cooked).to include("summary")
  end

  it "renders a thread as a normal message if there are no nested messages" do
    cooked = PrettyText.cook <<~MD
    [chat quote="jan;274;2023-12-06T04:15:00Z" channelId="2" threadId="140" threadTitle="NatureNotes"]
    original message
    [/chat]
    MD

    expect(cooked).not_to include('class="chat-transcript-thread"')
    expect(cooked).to include(
      "<div class=\"chat-transcript-messages\">\n<p>original message</p></div>",
    )
  end
end
