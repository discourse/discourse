import { trustHTML } from "@ember/template";
import { avatarUrl } from "discourse/lib/avatar-utils";
import { prioritizeNameInUx } from "discourse/lib/settings";
import CategorySectionLink from "discourse/lib/sidebar/user/categories-section/category-section-link";
import TagSectionLink from "discourse/lib/sidebar/user/tags-section/tag-section-link";
import { emojiUnescape } from "discourse/lib/text";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import VoiceParticipantSuffix from "../components/voice-participant-suffix.gjs";
import { channelKey } from "./sidebar-sections.js";

// Every link is prefixed by its kind, since a category, a tag and a chat
// channel can share a slug and section links are keyed by name.

function channelClasses(kind, unread) {
  const classes = ["concord-channel", `concord-channel--${kind}`];

  if (unread) {
    classes.push("concord-channel--unread");
  }

  return classes.join(" ");
}

// A category is a forum channel. Counts and routing come from core's link, only
// the prefix changes, so it reads as a channel type rather than a category.
export class ForumChannelLink extends CategorySectionLink {
  keywords = { navigation: [] };

  get sortName() {
    return this.category.name;
  }

  get channelKey() {
    return channelKey("forum", this.category.id);
  }

  // By its slug path, since a subcategory's slug is only unique under its
  // parent, and the long press finds a row's channel by name.
  get name() {
    return `forum-${Category.slugFor(this.category)}`;
  }

  get classNames() {
    return channelClasses("forum", !!this.activeCountable);
  }

  get prefixType() {
    return "icon";
  }

  get prefixValue() {
    return "fab-discourse";
  }

  get prefixColor() {
    return null;
  }
}

export class TagChannelLink extends TagSectionLink {
  keywords = { navigation: [] };

  get sortName() {
    return this.tag.name;
  }

  get channelKey() {
    return channelKey("tag", this.tag.id);
  }

  get name() {
    return `tag-${super.name}`;
  }

  get classNames() {
    return channelClasses("tag", this.totalUnread > 0 || this.totalNew > 0);
  }

  get prefixType() {
    return "icon";
  }

  get prefixValue() {
    return "tag";
  }

  get prefixColor() {
    return null;
  }
}

// A chat channel is a text channel. Chat's own sidebar link lives inside its
// initializer and can't be imported, so this is a lean version of it.
export class TextChannelLink {
  route = "chat.channel";
  prefixType = "icon";
  prefixValue = "hashtag";
  suffixType = "icon";
  suffixCSSClass = "unread";
  keywords = { navigation: [] };

  constructor({ channel }) {
    this.channel = channel;
  }

  get channelKey() {
    return channelKey("text", this.channel.id);
  }

  get name() {
    return `text-${this.channel.slugifiedTitle}`;
  }

  get sortName() {
    return this.channel.title;
  }

  get classNames() {
    const { tracking } = this.channel;
    const classes = [
      channelClasses(
        "text",
        tracking.unreadCount > 0 || tracking.watchedThreadsUnreadCount > 0
      ),
      `channel-${this.channel.id}`,
    ];

    if (this.channel.currentUserMembership?.muted) {
      classes.push("sidebar-section-link--muted");
    }

    return classes.join(" ");
  }

  get models() {
    return this.channel.routeModels;
  }

  get text() {
    return trustHTML(emojiUnescape(this.channel.escapedTitle));
  }

  get title() {
    return this.channel.escapedDescription
      ? trustHTML(this.channel.escapedDescription)
      : this.channel.escapedTitle;
  }

  get prefixBadge() {
    return this.channel.chatable?.read_restricted ? "lock" : null;
  }

  // Mentions get a count, a red pill; anything else unread just
  // gets the dot.
  get badgeText() {
    const mentions = this.channel.tracking.mentionCount;
    return mentions > 0 ? mentions.toString() : null;
  }

  get suffixValue() {
    const { tracking } = this.channel;

    if (tracking.mentionCount > 0) {
      return;
    }

    if (tracking.unreadCount > 0 || tracking.watchedThreadsUnreadCount > 0) {
      return "circle";
    }
  }
}

// A direct message, in the DM list: the other person's avatar (or a group
// icon), and their unread count as a badge.
export class DirectMessageLink {
  route = "chat.channel";
  keywords = { navigation: [] };

  constructor({ channel }) {
    this.channel = channel;
  }

  get name() {
    return `dm-${this.channel.id}`;
  }

  get channelKey() {
    return channelKey("dm", this.channel.id);
  }

  get #users() {
    return this.channel.chatable?.users || [];
  }

  get classNames() {
    const { tracking } = this.channel;
    const classes = [
      channelClasses("dm", tracking.unreadCount > 0),
      `channel-${this.channel.id}`,
    ];

    if (this.channel.currentUserMembership?.muted) {
      classes.push("sidebar-section-link--muted");
    }

    return classes.join(" ");
  }

  get models() {
    return this.channel.routeModels;
  }

  get text() {
    return trustHTML(emojiUnescape(this.channel.escapedTitle));
  }

  get title() {
    return this.channel.escapedTitle;
  }

  get prefixType() {
    return this.#users.length === 1 ? "image" : "icon";
  }

  get prefixValue() {
    return this.#users.length === 1
      ? avatarUrl(this.#users[0].avatar_template, "tiny")
      : "user-group";
  }

  get badgeText() {
    const unread = this.channel.tracking.unreadCount;
    return unread > 0 ? unread.toString() : null;
  }
}

// A live room is a voice channel. Named the way the live plugin names its
// own sidebar links, so its document-level click handler joins the room.
export class VoiceChannelLink {
  href = "#";
  prefixType = "icon";
  prefixValue = "volume-high";
  keywords = { navigation: [] };

  constructor({ room, voiceWebrtc }) {
    this.room = room;
    this.voiceWebrtc = voiceWebrtc;
  }

  get channelKey() {
    return channelKey("voice", this.room.id);
  }

  get name() {
    return `live-room-${this.room.id}`;
  }

  get sortName() {
    return this.room.name;
  }

  get text() {
    return this.room.name;
  }

  get title() {
    return this.room.description_excerpt || this.room.name;
  }

  get classNames() {
    const classes = ["concord-channel", "concord-channel--voice"];
    const state = this.voiceWebrtc?.connectionStateFor(this.room.id);

    if (state === "connected") {
      classes.push("sidebar-section-link--active");
    } else if (state === "connecting") {
      classes.push("concord-channel--connecting");
    }

    return classes.join(" ");
  }

  get prefixBadge() {
    return this.room.public ? null : "lock";
  }
}

// A stage shows this many listeners before folding the rest into a count.
const MAX_LISTENERS = 5;

/**
 * Who's in a voice channel, as rows under it, the way the live plugin's own
 * sidebar lists them: a stage's speakers first, then a few of its listeners.
 * The rows take the plugin's names and classes, so its styles, speaking ring
 * and right-click menu apply to them as they do there.
 *
 * @returns {Array} The rows, in order.
 */
export function voiceParticipantLinks({ room, voiceRooms, voiceWebrtc, user }) {
  const participants = [...(room.active_participants || [])];

  // The room's list catches up a moment after joining.
  if (
    user &&
    voiceWebrtc?.connectionStateFor(room.id) === "connected" &&
    !participants.some((participant) => participant?.id === user.id)
  ) {
    participants.push(user);
  }

  const link = (participant, options = {}) =>
    new VoiceParticipantLink({
      room,
      participant,
      voiceRooms,
      voiceWebrtc,
      user,
      ...options,
    });

  if (room.room_type !== "stage") {
    return participants.map((participant) => link(participant));
  }

  const onStage = ({ role }) => role === "moderator" || role === "speaker";
  const listeners = participants.filter((participant) => !onStage(participant));
  const links = participants
    .filter(onStage)
    .map((participant) => link(participant));

  listeners.slice(0, MAX_LISTENERS).forEach((participant, index) => {
    links.push(
      link(participant, { listener: true, firstListener: index === 0 })
    );
  });

  if (listeners.length > MAX_LISTENERS) {
    links.push(
      new VoiceListenerCountLink({
        room,
        count: listeners.length - MAX_LISTENERS,
      })
    );
  }

  return links;
}

class VoiceParticipantLink {
  href = "#";
  prefixType = "image";
  keywords = { navigation: [] };
  suffixComponent = VoiceParticipantSuffix;

  constructor({
    room,
    participant,
    voiceRooms,
    voiceWebrtc,
    user,
    listener,
    firstListener,
  }) {
    this.room = room;
    this.participant = participant;
    this.voiceRooms = voiceRooms;
    this.voiceWebrtc = voiceWebrtc;
    this.user = user;
    this.listener = listener;
    this.firstListener = firstListener;
  }

  get #isUser() {
    return this.participant.id === this.user?.id;
  }

  get #speaking() {
    return (
      this.voiceRooms?.isParticipantSpeaking?.(
        this.room.id,
        this.participant.id
      ) &&
      !this.participant.is_muted &&
      !this.participant.is_deafened
    );
  }

  get #handRaised() {
    return this.room.room_type === "stage" && !!this.participant.hand_raised_at;
  }

  get #ptt() {
    return this.#isUser && !!this.voiceWebrtc?.pttEnabled;
  }

  get name() {
    return `live-participant-${this.room.id}-${this.participant.id}`;
  }

  get text() {
    return prioritizeNameInUx(this.participant.name)
      ? this.participant.name
      : this.participant.username;
  }

  get title() {
    return this.#speaking
      ? `${this.text} — ${i18n("live.participant.status_speaking")}`
      : this.text;
  }

  get prefixValue() {
    return avatarUrl(this.participant.avatar_template, "small");
  }

  get classNames() {
    const { participant } = this;
    return [
      "live-sidebar-participant",
      this.listener && "live-sidebar-participant--listener",
      this.firstListener && "live-sidebar-participant--listeners-start",
      this.#speaking && "live-sidebar-participant--speaking",
      participant.is_muted && "live-sidebar-participant--muted",
      participant.is_deafened && "live-sidebar-participant--deafened",
      this.#handRaised && "live-sidebar-participant--hand-raised",
      participant.idle_state === "idle" && "live-sidebar-participant--idle",
      participant.idle_state === "afk" && "live-sidebar-participant--afk",
    ]
      .filter(Boolean)
      .join(" ");
  }

  get suffixArgs() {
    return {
      isHandRaised: this.#handRaised,
      isScreenSharing: this.participant.is_screen_sharing,
      isVideoOn: this.participant.is_video_on,
      isPtt: this.#ptt,
      isMuted: this.participant.is_muted,
      isDeafened: this.participant.is_deafened,
    };
  }
}

class VoiceListenerCountLink {
  href = "#";
  prefixType = "icon";
  prefixValue = "users";
  keywords = { navigation: [] };
  classNames =
    "live-sidebar-participant live-sidebar-participant--listener-count";

  constructor({ room, count }) {
    this.room = room;
    this.count = count;
  }

  get name() {
    return `live-listener-count-${this.room.id}`;
  }

  get text() {
    return i18n("live.stage.more_listeners", { count: this.count });
  }
}
