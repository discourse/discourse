/**
 * Options exposed by the shared chat channel list menu for each sidebar /
 * drawer / mobile section. Used by the cover sidebar section headers and by
 * the non-sidebar list headers so both stay in sync.
 */
export const CHANNEL_LIST_SECTION_OPTIONS = {
  channels: {
    showCreateChannel: true,
    showBrowse: true,
    showFilter: true,
    showSort: true,
  },
  starred: { showFilter: true, showSort: true },
  dms: { showNewMessage: true, showFilter: true, showSort: true },
};
