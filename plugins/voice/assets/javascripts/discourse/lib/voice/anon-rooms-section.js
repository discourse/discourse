import { avatarUrl } from "discourse/lib/avatar-utils";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { i18n } from "discourse-i18n";
import roomIcon, { roomBadge } from "./room-icon";

export default function buildAnonRoomsSection(roomsService) {
  return (BaseSection, BaseLink) => {
    class RoomLink extends BaseLink {
      constructor(room) {
        super(...arguments);
        this.room = room;
      }

      get name() {
        return `voice-room-${this.room.id}`;
      }

      get classNames() {
        return "voice-sidebar-link";
      }

      get href() {
        return "#";
      }

      get title() {
        return (
          this.room.description_excerpt ||
          this.room.name ||
          i18n("voice.room.join")
        );
      }

      get text() {
        return this.room.name;
      }

      get prefixType() {
        return "icon";
      }

      get prefixValue() {
        return roomIcon(this.room);
      }

      get prefixBadge() {
        return roomBadge(this.room);
      }
    }

    class ParticipantLink extends BaseLink {
      constructor(room, participant, options = {}) {
        super(...arguments);
        this.room = room;
        this.participant = participant;
        this.isStageListener = options.isListener || false;
        this.isFirstListener = options.isFirstListener || false;
      }

      get name() {
        return `voice-participant-${this.room.id}-${this.participant.id}`;
      }

      get classNames() {
        const classes = ["voice-sidebar-participant"];

        if (this.isStageListener) {
          classes.push("voice-sidebar-participant--listener");
        }

        if (this.isFirstListener) {
          classes.push("voice-sidebar-participant--listeners-start");
        }

        // Speaking is detected client-side from live media streams, which
        // anonymous visitors never hold.
        if (this.participant.is_muted) {
          classes.push("voice-sidebar-participant--muted");
        }

        if (this.participant.is_deafened) {
          classes.push("voice-sidebar-participant--deafened");
        }

        if (this.participant.idle_state === "idle") {
          classes.push("voice-sidebar-participant--idle");
        } else if (this.participant.idle_state === "afk") {
          classes.push("voice-sidebar-participant--afk");
        }

        return classes.join(" ");
      }

      get href() {
        return "#";
      }

      get displayName() {
        return prioritizeNameInUx(this.participant.name)
          ? this.participant.name
          : this.participant.username;
      }

      get title() {
        return this.displayName;
      }

      get text() {
        return this.displayName;
      }

      get prefixType() {
        return "image";
      }

      get prefixValue() {
        return avatarUrl(this.participant.avatar_template, "small");
      }
    }

    class ListenerCountLink extends BaseLink {
      constructor(room, count) {
        super(...arguments);
        this.room = room;
        this.count = count;
      }

      get name() {
        return `voice-listener-count-${this.room.id}`;
      }

      get classNames() {
        return "voice-sidebar-participant voice-sidebar-participant--listener-count";
      }

      get href() {
        return "#";
      }

      get title() {
        return this.text;
      }

      get text() {
        return i18n("voice.stage.more_listeners", { count: this.count });
      }

      get prefixType() {
        return "icon";
      }

      get prefixValue() {
        return "users";
      }
    }

    return class AnonRoomsSection extends BaseSection {
      name = "voice-rooms";
      text = i18n("voice.sidebar.title");
      title = i18n("voice.sidebar.title");

      get displaySection() {
        return (roomsService.rooms?.length || 0) > 0;
      }

      get links() {
        const links = [];

        for (const room of roomsService.rooms || []) {
          links.push(new RoomLink(room));

          const participants = room.active_participants || [];

          if (room.room_type === "stage" && participants.length > 0) {
            const speakers = participants.filter((participant) => {
              const role = participant.role;
              return role === "moderator" || role === "speaker";
            });
            const listeners = participants.filter((participant) => {
              const role = participant.role;
              return role !== "moderator" && role !== "speaker";
            });

            for (const participant of speakers) {
              links.push(new ParticipantLink(room, participant));
            }

            const maxVisibleListeners = 5;
            listeners
              .slice(0, maxVisibleListeners)
              .forEach((participant, index) => {
                links.push(
                  new ParticipantLink(room, participant, {
                    isListener: true,
                    isFirstListener: index === 0,
                  })
                );
              });

            if (listeners.length > maxVisibleListeners) {
              links.push(
                new ListenerCountLink(
                  room,
                  listeners.length - maxVisibleListeners
                )
              );
            }
          } else {
            for (const participant of participants) {
              links.push(new ParticipantLink(room, participant));
            }
          }
        }

        return links;
      }
    };
  };
}
