// Barrel for the drawer's route components, so `chat-drawer-router` can pull them in with a
// single dynamic import. The drawer outlet renders on every page, so importing these eagerly
// would put most of chat's UI in the bundle for every request.
export { default as Browse } from "../components/chat/drawer-routes/browse";
export { default as Channel } from "../components/chat/drawer-routes/channel";
export { default as ChannelInfoMembers } from "../components/chat/drawer-routes/channel-info-members";
export { default as ChannelInfoSettings } from "../components/chat/drawer-routes/channel-info-settings";
export { default as ChannelPins } from "../components/chat/drawer-routes/channel-pins";
export { default as ChannelThread } from "../components/chat/drawer-routes/channel-thread";
export { default as ChannelThreads } from "../components/chat/drawer-routes/channel-threads";
export { default as Channels } from "../components/chat/drawer-routes/channels";
export { default as DirectMessages } from "../components/chat/drawer-routes/direct-messages";
export { default as Search } from "../components/chat/drawer-routes/search";
export { default as StarredChannels } from "../components/chat/drawer-routes/starred-channels";
export { default as Threads } from "../components/chat/drawer-routes/threads";
