export default function applyDefaultHandlers(helpers) {
  this.post("/chat/api/channels/:channel_id/drafts", () =>
    helpers.response({})
  );
  this.post("/chat/api/channels/:channel_id/threads/:thread_id/drafts", () =>
    helpers.response({})
  );
}
