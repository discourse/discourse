import { ajax } from "discourse/lib/ajax";
import domFromString from "discourse/lib/dom-from-string";
import getURL from "discourse/lib/get-url";
import { getHashtagTypeClasses } from "discourse/lib/hashtag-type-registry";
import { iconHTML } from "discourse/lib/icon-library";
import { emojiUnescape } from "discourse/lib/text";
import { userPath } from "discourse/lib/url";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default function groupChatTranscripts(
  element,
  { site, chatChannelsManager }
) {
  const transcripts = [...element.querySelectorAll(".chat-transcript")].filter(
    (transcript) =>
      !transcript.parentElement.closest(
        ".chat-transcript, .chat-transcript-group"
      )
  );

  const groups = [];
  let group;
  transcripts.forEach((transcript) => {
    if (
      !group ||
      transcript.previousElementSibling !== group ||
      !isContinuation(transcript)
    ) {
      group = buildGroup(transcript, { site, chatChannelsManager });
      groups.push(group);
      transcript.before(group);
    }

    group.querySelector(".chat-transcript-group__body").append(transcript);
    expandThread(transcript);
  });

  groups.forEach((transcriptGroup) => {
    const channelUrl = linkableChannelUrl(transcriptGroup);
    if (channelUrl) {
      linkTimestamps(transcriptGroup, channelUrl);
      linkThreadTitles(transcriptGroup, channelUrl);
    }
    linkAuthors(transcriptGroup);
    promoteSoleThread(transcriptGroup);
  });
}

// ids come from cooked attributes a post author can write, so they're encoded to
// keep each one a single path segment
function channelPath(channelId) {
  return getURL(`/chat/c/-/${encodeURIComponent(channelId)}`);
}

function linkableChannelUrl(group) {
  const first = group.querySelector(".chat-transcript");
  const { channelId } = first.dataset;

  // an unlinked first timestamp means links were left out on purpose (archives)
  if (!channelId || !ownTimestamp(first)?.querySelector(":scope > a")) {
    return;
  }

  return channelPath(channelId);
}

function linkTimestamps(group, channelUrl) {
  group.querySelectorAll(".chat-transcript").forEach((transcript) => {
    const unlinked = ownTimestamp(transcript)?.querySelector(
      ":scope > span[title]"
    );
    if (!unlinked) {
      return;
    }

    const { messageId } = transcript.dataset;
    const threadId = transcript.parentElement.closest(
      ".chat-transcript[data-thread-id]"
    )?.dataset.threadId;

    const link = document.createElement("a");
    link.href = threadId
      ? `${channelUrl}/t/${encodeURIComponent(threadId)}/${encodeURIComponent(messageId)}`
      : `${channelUrl}/${encodeURIComponent(messageId)}`;
    link.title = unlinked.title;
    link.append(...unlinked.childNodes);
    unlinked.replaceWith(link);
  });
}

function linkThreadTitles(group, channelUrl) {
  group
    .querySelectorAll(".chat-transcript[data-thread-id]")
    .forEach((transcript) => {
      const title = transcript.querySelector(
        ".chat-transcript-thread-header__title"
      );
      if (!title || title.querySelector(":scope > a")) {
        return;
      }

      const link = document.createElement("a");
      link.href = `${channelUrl}/t/${encodeURIComponent(transcript.dataset.threadId)}`;
      link.append(...title.childNodes);
      title.append(link);
    });
}

function promoteSoleThread(group) {
  const header = group.querySelector(".chat-transcript-group__header");
  const body = group.querySelector(".chat-transcript-group__body");
  const threadHeader = body.querySelector(".chat-transcript-thread-header");

  if (!header || !threadHeader || body.children.length !== 1) {
    return;
  }

  const thread = document.createElement("span");
  thread.classList.add("chat-transcript-group__thread");
  thread.append(...threadHeader.childNodes);
  threadHeader.remove();

  header.querySelector(".chat-transcript-group__channel").after(thread);
}

function linkAuthors(group) {
  group.querySelectorAll(".chat-transcript").forEach((transcript) => {
    const { username } = transcript.dataset;
    if (!username) {
      return;
    }

    const avatarLink = wrapInUserLink(
      transcript.querySelector(".chat-transcript-user-avatar"),
      username
    );
    // the username link carries the accessible name; this is a duplicate target
    avatarLink?.setAttribute("tabindex", "-1");
    avatarLink?.setAttribute("aria-hidden", "true");

    wrapInUserLink(
      transcript.querySelector(".chat-transcript-username"),
      username
    );
  });
}

function wrapInUserLink(element, username) {
  // composer previews cook without avatars, leaving the slot empty
  if (!element?.textContent.trim() && !element?.querySelector("img")) {
    return;
  }

  if (element.querySelector(":scope > a")) {
    return;
  }

  const link = document.createElement("a");
  link.href = userPath(encodeURIComponent(username.toLowerCase()));
  link.dataset.userCard = username;
  link.append(...element.childNodes);
  element.append(link);
  return link;
}

// a thread's replies are nested inside it, after its own timestamp
function ownTimestamp(transcript) {
  return transcript.querySelector(".chat-transcript-datetime");
}

// Only a transcript's first block names the channel. Later blocks aren't always
// marked chained, e.g. one author's messages are split where a thread starts.
function isContinuation(transcript) {
  return !transcript.dataset.channelName;
}

function expandThread(transcript) {
  const details = transcript.querySelector(":scope > details");
  if (!details) {
    return;
  }

  const summary = details.querySelector(":scope > summary");
  summary?.replaceWith(...summary.childNodes);
  details.replaceWith(...details.childNodes);
}

function buildGroup(transcript, services) {
  const group = document.createElement("div");
  group.classList.add("chat-transcript-group");

  const { channelName, channelId } = transcript.dataset;
  if (channelName) {
    group.append(buildTranscriptHeader(channelName, channelId, services));

    transcript.querySelector(":scope > .chat-transcript-meta")?.remove();
    transcript
      .querySelectorAll(".chat-transcript-channel")
      .forEach((link) => link.remove());
  }

  // the body scrolls when long, so it must be reachable by keyboard
  const body = document.createElement("div");
  body.classList.add("chat-transcript-group__body");
  body.tabIndex = 0;
  body.setAttribute("role", "region");
  body.setAttribute(
    "aria-label",
    channelName
      ? i18n("chat.quote.transcript_region", { channel: channelName })
      : i18n("chat.quote.transcript_label")
  );
  group.append(body);

  return group;
}

export function buildTranscriptHeader(channelName, channelId, services) {
  const header = document.createElement("div");
  header.classList.add("chat-transcript-group__header");

  const channel = document.createElement(channelId ? "a" : "span");
  channel.classList.add("hashtag-cooked", "chat-transcript-group__channel");
  if (channelId) {
    channel.href = channelPath(channelId);
  }
  channel.innerHTML = `${channelIconHTML(channelId, services)}<span>${emojiUnescape(
    escapeExpression(channelName)
  )}</span>`;

  // channels the user hasn't joined (or that haven't loaded yet) need a lookup
  if (
    channelId &&
    getHashtagTypeClasses().channel &&
    !findChannel(channelId, services)
  ) {
    fetchChannelEmoji(channelId).then((emoji) => {
      if (emoji) {
        channel.firstElementChild.replaceWith(
          domFromString(channelIconHTML(channelId, services, emoji))[0]
        );
      }
    });
  }

  const label = document.createElement("span");
  label.classList.add("chat-transcript-group__label");
  label.textContent = i18n("chat.quote.transcript_label");

  header.append(channel, label);
  return header;
}

function channelIconHTML(channelId, services, emoji) {
  const icon = services.site.hashtag_icons?.channel ?? "comment";
  const channelType = getHashtagTypeClasses().channel;

  if (channelType && channelId) {
    return channelType.generateIconHTML({
      id: parseInt(channelId, 10),
      icon,
      emoji: emoji ?? findChannel(channelId, services)?.emoji,
    });
  }

  return iconHTML(icon);
}

const channelEmojiRequests = new Map();

function fetchChannelEmoji(channelId) {
  if (!channelEmojiRequests.has(channelId)) {
    channelEmojiRequests.set(
      channelId,
      ajax("/hashtags/by-ids", { data: { channel: [channelId] } })
        .then((result) => result.channel?.[0]?.emoji)
        .catch(() => null)
    );
  }
  return channelEmojiRequests.get(channelId);
}

function findChannel(channelId, { chatChannelsManager }) {
  const id = parseInt(channelId, 10);
  return chatChannelsManager?.channels.find((channel) => channel.id === id);
}
