export default {
  resource: "user.userActivity",

  map() {
    this.route("sharedAiArtifacts", { path: "shared-ai-artifacts" });
    this.route("sharedAiConversations", { path: "shared-ai-conversations" });
    this.route("sharedArtifacts", { path: "shared-artifacts" });
  },
};
