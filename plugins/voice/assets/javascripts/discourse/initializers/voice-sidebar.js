import { later, next } from "@ember/runloop";
import noop from "discourse/helpers/noop";
import { avatarUrl } from "discourse/lib/avatar-utils";
import getURL from "discourse/lib/get-url";
import { withPluginApi } from "discourse/lib/plugin-api";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { i18n } from "discourse-i18n";
import VoiceCreateRoomModal from "discourse/plugins/voice/discourse/components/modal/voice-create-room";
import VoiceParticipantSidebarContextMenu from "discourse/plugins/voice/discourse/components/voice-participant-sidebar-context-menu";
import VoiceParticipantSidebarSuffix from "discourse/plugins/voice/discourse/components/voice-participant-sidebar-suffix";
import VoiceRoomSidebarContextMenu from "discourse/plugins/voice/discourse/components/voice-room-sidebar-context-menu";
import buildAnonRoomsSection from "../lib/voice/anon-rooms-section";
import { humanKeyName } from "../lib/voice/ptt-utils";
import roomIcon, { roomBadge } from "../lib/voice/room-icon";
import virtualElementFromEvent from "../lib/voice/virtual-element-from-event";

const LINK_NAME_PREFIX = "voice-room-";
const CHAT_PANEL = "chat";
let sidebarClickHandler;
let sidebarContextMenuHandler;

export default {
  name: "voice-sidebar",
  initialize(owner) {
    withPluginApi((api) => {
      const currentUser = api.getCurrentUser();
      const siteSettings = owner.lookup("service:site-settings");
      const site = owner.lookup("service:site");

      if (!siteSettings.voice_enabled) {
        return;
      }

      // Anonymous visitors only see the sidebar when Voice is open to
      // everyone. They can browse public rooms but are sent to log in on click.
      if (!currentUser && !site.voice_public_access) {
        return;
      }

      const roomsService = owner.lookup("service:voice-rooms");

      if (!currentUser) {
        // API sections render after Discourse's normal navigation sections,
        // matching the location of the logged-in rooms section.
        api.addSidebarSection(buildAnonRoomsSection(roomsService));

        if (sidebarClickHandler) {
          document.removeEventListener("click", sidebarClickHandler);
        }

        sidebarClickHandler = (event) => {
          const anchor =
            event
              .composedPath?.()
              ?.find?.(
                (node) =>
                  node instanceof HTMLElement &&
                  node.matches?.(
                    ".sidebar-section-link[data-link-name^='voice-']"
                  )
              ) ||
            event.target?.closest?.(
              ".sidebar-section-link[data-link-name^='voice-']"
            );

          if (!anchor) {
            return;
          }

          event.preventDefault();
          event.stopPropagation();
          owner.lookup("route:application").send("showLogin");
        };

        document.addEventListener("click", sidebarClickHandler);
        return;
      }

      const voiceWebrtc = owner.lookup("service:voice-webrtc");
      const routerService = owner.lookup("service:router");
      const menuService = owner.lookup("service:menu");
      const modalService = owner.lookup("service:modal");
      const capabilities = owner.lookup("service:capabilities");
      const sidebarState = owner.lookup("service:sidebar-state");

      const buildRoomsSection =
        ({ sectionName, chatPanel } = {}) =>
        (BaseSection, BaseLink) => {
          const RoomsLink = class extends BaseLink {
            constructor({ room, webrtcService, user, menu }) {
              super(...arguments);
              this.room = room;
              this.voiceWebrtc = webrtcService;
              this.currentUser = user;
              this.menuService = menu;
            }

            get hoverType() {
              return "icon";
            }

            get hoverValue() {
              if (!this.currentUser || capabilities.isIpadOS) {
                return null;
              }
              return "ellipsis-vertical";
            }

            get hoverTitle() {
              return i18n("voice.room.menu_title");
            }

            get hoverAction() {
              if (!this.currentUser || capabilities.isIpadOS) {
                return noop;
              }

              return (event, onMenuClose) => {
                event.stopPropagation();
                event.preventDefault();

                const anchor =
                  event.target.closest(".sidebar-section-link") || event.target;

                this.menuService.show(anchor, {
                  identifier: "voice-room-menu",
                  component: VoiceRoomSidebarContextMenu,
                  placement: "right",
                  data: { room: this.room },
                  onClose: onMenuClose,
                });
              };
            }

            get name() {
              return `voice-room-${this.room.id}`;
            }

            get classNames() {
              const classes = ["voice-sidebar-link"];
              const state = this.voiceWebrtc.connectionStateFor(this.room.id);

              if (state === "connected") {
                classes.push("sidebar-section-link--active");
              } else if (state === "connecting") {
                classes.push("voice-sidebar-link--connecting");
              }

              return classes.join(" ");
            }

            get href() {
              return "#";
            }

            get title() {
              const state = this.voiceWebrtc.connectionStateFor(this.room.id);

              if (state === "connecting") {
                return i18n("voice.room.connecting");
              }

              if (state === "connected") {
                return i18n("voice.room.open_page");
              }

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

            get #hasActiveVideo() {
              return (this.room.active_participants || []).some(
                (participant) =>
                  participant?.is_video_on || participant?.is_screen_sharing
              );
            }

            get suffixType() {
              if (
                this.voiceWebrtc.connectionStateFor(this.room.id) ===
                  "connecting" ||
                this.#hasActiveVideo
              ) {
                return "icon";
              }
              return null;
            }

            get suffixValue() {
              if (
                this.voiceWebrtc.connectionStateFor(this.room.id) ===
                "connecting"
              ) {
                return "spinner";
              }
              if (this.#hasActiveVideo) {
                return "video";
              }
              return null;
            }

            getParticipantsForSummary() {
              const participants = this.room.active_participants || [];

              if (!this.currentUser) {
                return participants;
              }

              if (
                this.voiceWebrtc.connectionStateFor(this.room.id) !==
                "connected"
              ) {
                return participants;
              }

              if (
                participants.some(
                  (participant) => participant?.id === this.currentUser.id
                )
              ) {
                return participants;
              }

              return [
                ...participants,
                {
                  id: this.currentUser.id,
                  username: this.currentUser.username,
                  name: this.currentUser.name,
                  avatar_template: this.currentUser.avatar_template,
                },
              ];
            }
          };

          const ParticipantLink = class extends BaseLink {
            constructor({
              room,
              participant,
              webrtcService,
              user,
              menu,
              canManageRoom,
              isListener,
              isFirstListener,
            }) {
              super(...arguments);
              this.room = room;
              this.participant = participant;
              this.voiceWebrtc = webrtcService;
              this.currentUser = user;
              this.menuService = menu;
              this.canManageRoom = canManageRoom;
              this.isStageListener = isListener || false;
              this.isFirstListener = isFirstListener || false;
            }

            get #isCurrentUser() {
              return this.participant.id === this.currentUser?.id;
            }

            get #showMenu() {
              return (
                !capabilities.isIpadOS &&
                !!this.currentUser &&
                this.voiceWebrtc.connectionStateFor(this.room.id) ===
                  "connected"
              );
            }

            get #isAudiblySpeaking() {
              return (
                roomsService.isParticipantSpeaking(
                  this.room.id,
                  this.participant.id
                ) &&
                !this.participant.is_muted &&
                !this.participant.is_deafened
              );
            }

            get #isHandRaised() {
              return (
                this.room.room_type === "stage" &&
                !!this.participant.hand_raised_at
              );
            }

            get hoverType() {
              return this.#showMenu ? "icon" : null;
            }

            get hoverValue() {
              return this.#showMenu ? "ellipsis-vertical" : null;
            }

            get hoverTitle() {
              return i18n("voice.participant.menu_title");
            }

            get hoverAction() {
              if (!this.#showMenu) {
                return noop;
              }

              return (event, onMenuClose) => {
                event.stopPropagation();
                event.preventDefault();

                const anchor =
                  event.target.closest(".sidebar-section-link") || event.target;

                this.menuService.show(anchor, {
                  identifier: "voice-participant-menu",
                  component: VoiceParticipantSidebarContextMenu,
                  placement: "right",
                  data: {
                    room: this.room,
                    participant: this.participant,
                    canManageRoom: this.canManageRoom,
                    isCurrentUser: this.#isCurrentUser,
                  },
                  onClose: onMenuClose,
                });
              };
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

              if (this.#isAudiblySpeaking) {
                classes.push("voice-sidebar-participant--speaking");
              }

              if (this.participant.is_muted) {
                classes.push("voice-sidebar-participant--muted");
              }

              if (this.participant.is_deafened) {
                classes.push("voice-sidebar-participant--deafened");
              }

              if (this.#isHandRaised) {
                classes.push("voice-sidebar-participant--hand-raised");
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

            get #displayName() {
              return prioritizeNameInUx(this.participant.name)
                ? this.participant.name
                : this.participant.username;
            }

            get title() {
              let title = this.#displayName;
              if (this.#isCurrentUser && this.voiceWebrtc.pttEnabled) {
                title = `${title} — ${i18n("voice.ptt.badge", { key: humanKeyName(this.voiceWebrtc.pttKey) })}`;
              }
              // The speaking wave is a CSS pseudo-element and can't carry
              // its own accessible label, so surface the state here instead.
              if (this.#isAudiblySpeaking) {
                title = `${title} — ${i18n("voice.participant.status_speaking")}`;
              }
              return title;
            }

            get text() {
              return this.#displayName;
            }

            // A custom suffix component (instead of the single suffixValue
            // slot) so every state icon can show simultaneously on the right
            // edge. The speaking wave renders over the avatar via the
            // `--speaking` class.
            get suffixComponent() {
              return VoiceParticipantSidebarSuffix;
            }

            get suffixArgs() {
              return {
                isHandRaised: this.#isHandRaised,
                isScreenSharing: this.participant.is_screen_sharing,
                isVideoOn: this.participant.is_video_on,
                isPtt: this.#isCurrentUser && this.voiceWebrtc.pttEnabled,
                isMuted: this.participant.is_muted,
                isDeafened: this.participant.is_deafened,
              };
            }

            get prefixType() {
              return "image";
            }

            get prefixValue() {
              return avatarUrl(this.participant.avatar_template, "small");
            }
          };

          const ListenerCountLink = class extends BaseLink {
            constructor({ room, count }) {
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

            get text() {
              return i18n("voice.stage.more_listeners", {
                count: this.count,
              });
            }

            get prefixType() {
              return "icon";
            }

            get prefixValue() {
              return "users";
            }
          };

          const RoomsSection = class extends BaseSection {
            name = sectionName;
            text = i18n("voice.sidebar.title");
            title = i18n("voice.sidebar.title");

            constructor() {
              super(...arguments);
              this.voiceRooms = roomsService;
            }

            get actions() {
              if (this.voiceRooms?.canCreateRoom) {
                return [
                  {
                    id: "createVoiceRoom",
                    title: i18n("voice.sidebar.create"),
                    action: () => modalService.show(VoiceCreateRoomModal),
                  },
                ];
              }
              return [];
            }

            get actionsIcon() {
              return "plus";
            }

            get displaySection() {
              // In combined mode the main-panel copy already renders; avoid a duplicate.
              if (chatPanel && sidebarState.combinedMode) {
                return false;
              }

              return (
                (this.voiceRooms?.rooms?.length || 0) > 0 ||
                this.voiceRooms?.canCreateRoom
              );
            }

            get links() {
              const result = [];

              for (const room of this.voiceRooms?.rooms || []) {
                const roomLink = new RoomsLink({
                  room,
                  webrtcService: voiceWebrtc,
                  user: currentUser,
                  menu: menuService,
                });
                result.push(roomLink);

                const canManageRoom = room.can_manage;
                const participants = roomLink.getParticipantsForSummary();

                if (room.room_type === "stage" && participants.length > 0) {
                  const speakers = participants.filter((p) => {
                    const role = p.role;
                    return role === "moderator" || role === "speaker";
                  });
                  const listeners = participants.filter((p) => {
                    const role = p.role;
                    return role !== "moderator" && role !== "speaker";
                  });

                  for (const participant of speakers) {
                    result.push(
                      new ParticipantLink({
                        room,
                        participant,
                        webrtcService: voiceWebrtc,
                        user: currentUser,
                        menu: menuService,
                        canManageRoom,
                      })
                    );
                  }

                  const maxVisibleListeners = 5;
                  const visibleListeners = listeners.slice(
                    0,
                    maxVisibleListeners
                  );

                  visibleListeners.forEach((participant, index) => {
                    result.push(
                      new ParticipantLink({
                        room,
                        participant,
                        webrtcService: voiceWebrtc,
                        user: currentUser,
                        menu: menuService,
                        canManageRoom,
                        isListener: true,
                        isFirstListener: index === 0,
                      })
                    );
                  });

                  if (listeners.length > maxVisibleListeners) {
                    result.push(
                      new ListenerCountLink({
                        room,
                        count: listeners.length - maxVisibleListeners,
                      })
                    );
                  }
                } else {
                  for (const participant of participants) {
                    result.push(
                      new ParticipantLink({
                        room,
                        participant,
                        webrtcService: voiceWebrtc,
                        user: currentUser,
                        menu: menuService,
                        canManageRoom,
                      })
                    );
                  }
                }
              }

              return result;
            }
          };

          return RoomsSection;
        };

      api.addSidebarSection(buildRoomsSection({ sectionName: "voice-rooms" }));

      // Mirror the section into the chat panel so rooms stay visible in the
      // full-screen chat separate sidebar. The chat panel is registered by the
      // chat plugin's own initializer, whose relative order isn't guaranteed,
      // so poll until the panel shows up. The panel may also have rendered by
      // then, and pushes into its sections array aren't tracked, so reassign
      // the array to make a late-registered section render.
      const registerChatRoomsSection = () => {
        const foundChatPanel = (sidebarState.panels || []).find(
          (panel) => panel.key === CHAT_PANEL
        );

        if (!foundChatPanel) {
          return false;
        }

        api.addSidebarSection(
          buildRoomsSection({
            sectionName: "voice-rooms-chat",
            chatPanel: true,
          }),
          CHAT_PANEL
        );
        foundChatPanel.sections = [...foundChatPanel.sections];
        return true;
      };

      if (siteSettings.chat_enabled && !registerChatRoomsSection()) {
        // The panel never appears for users who can't chat; give up quietly
        // after a few seconds.
        let attempts = 0;
        const retryRegistration = () => {
          if (registerChatRoomsSection() || ++attempts >= 50) {
            return;
          }
          later(retryRegistration, 100);
        };
        next(retryRegistration);
      }

      if (sidebarClickHandler) {
        document.removeEventListener("click", sidebarClickHandler);
      }

      sidebarClickHandler = async (event) => {
        const findAnchor = (selector) =>
          event
            .composedPath?.()
            ?.find?.(
              (node) => node instanceof HTMLElement && node.matches?.(selector)
            ) || event.target?.closest?.(selector);

        const participantAnchor = findAnchor(
          ".sidebar-section-link[data-link-name^='voice-participant-']"
        );

        const roomAnchor = findAnchor(
          ".sidebar-section-link[data-link-name^='voice-room-']"
        );

        if (participantAnchor) {
          event.preventDefault();
          event.stopPropagation();
          return;
        }

        if (!roomAnchor) {
          return;
        }

        event.preventDefault();
        event.stopPropagation();

        const linkName = roomAnchor.dataset?.linkName;
        if (!linkName?.startsWith(LINK_NAME_PREFIX)) {
          return;
        }

        const roomId = parseInt(
          linkName.substring(LINK_NAME_PREFIX.length),
          10
        );
        const room = Number.isNaN(roomId)
          ? null
          : roomsService.roomById(roomId);

        if (!room) {
          return;
        }

        const connectionState = voiceWebrtc.connectionStateFor(room.id);

        if (event.shiftKey) {
          // Hand the call over cleanly: two windows joined as the same user
          // would fight over presence.
          if (connectionState === "connected") {
            voiceWebrtc.leave(room);
          }

          window.open(getURL(`/voice/r/${room.slug}?join`));
          return;
        }

        if (connectionState === "connecting") {
          return;
        }

        if (connectionState === "connected") {
          const currentRoute = routerService.currentRoute;
          const onRoomPage =
            currentRoute?.name === "voice-room" &&
            currentRoute?.params?.slug === room.slug;

          if (!onRoomPage) {
            routerService.transitionTo("voice-room", room.slug);
          }
        } else {
          await voiceWebrtc.join(room);
        }
      };

      document.addEventListener("click", sidebarClickHandler);

      if (sidebarContextMenuHandler) {
        document.removeEventListener("contextmenu", sidebarContextMenuHandler);
      }

      sidebarContextMenuHandler = (event) => {
        const findAnchor = (selector) =>
          event
            .composedPath?.()
            ?.find?.(
              (node) => node instanceof HTMLElement && node.matches?.(selector)
            ) || event.target?.closest?.(selector);

        const participantAnchor = findAnchor(
          ".sidebar-section-link[data-link-name^='voice-participant-']"
        );

        if (participantAnchor) {
          event.preventDefault();
          event.stopPropagation();

          const linkName = participantAnchor.dataset?.linkName;
          const suffix = linkName?.replace("voice-participant-", "");
          const dashIdx = suffix?.indexOf("-");
          if (!suffix || dashIdx < 1) {
            return;
          }

          const roomId = parseInt(suffix.substring(0, dashIdx), 10);
          const participantId = parseInt(suffix.substring(dashIdx + 1), 10);
          const room = roomsService.roomById(roomId);
          if (!room) {
            return;
          }

          const participant = (room.active_participants || []).find(
            (p) => p.id === participantId
          );
          if (!participant) {
            return;
          }

          // The menu only offers audio controls for a call the user is in.
          if (voiceWebrtc.connectionStateFor(room.id) !== "connected") {
            return;
          }

          menuService.show(virtualElementFromEvent(event), {
            identifier: "voice-participant-menu",
            component: VoiceParticipantSidebarContextMenu,
            placement: "bottom-start",
            data: {
              room,
              participant,
              canManageRoom: room.can_manage,
              isCurrentUser: participant.id === currentUser?.id,
            },
          });
          return;
        }

        const roomAnchor = findAnchor(
          ".sidebar-section-link[data-link-name^='voice-room-']"
        );

        if (!roomAnchor) {
          return;
        }

        event.preventDefault();
        event.stopPropagation();

        const linkName = roomAnchor.dataset?.linkName;
        if (!linkName?.startsWith(LINK_NAME_PREFIX)) {
          return;
        }

        const roomId = parseInt(
          linkName.substring(LINK_NAME_PREFIX.length),
          10
        );
        const room = Number.isNaN(roomId)
          ? null
          : roomsService.roomById(roomId);

        if (!room) {
          return;
        }

        menuService.show(virtualElementFromEvent(event), {
          identifier: "voice-room-menu",
          component: VoiceRoomSidebarContextMenu,
          placement: "bottom-start",
          data: { room },
        });
      };

      document.addEventListener("contextmenu", sidebarContextMenuHandler);
    });
  },
};
