// Utility for detecting and managing embed mode.
// When embed_mode=true is in the URL, Discourse renders in a minimal mode
// suitable for embedding in an iframe on external sites.
const EmbedMode = {
  enabled: false,

  init() {
    const params = new URLSearchParams(window.location.search);
    this.enabled = params.get("embed_mode") === "true";

    if (this.enabled) {
      document.body.classList.add("embed-mode");
    }
  },
};

EmbedMode.init();

export default EmbedMode;
