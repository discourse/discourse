/** Recorded server responses, keyed by request URL. */
export default /** @type {Record<string, Record<string, unknown>>} */ ({
  "/chat/api/me/channels": {
    public_channels: [],
    direct_message_channels: [],
    meta: { message_bus_last_ids: {} },
    tracking: {},
  },
});
