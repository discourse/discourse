export default {
  name: "discourse-workflows-composer-paused",

  initialize(container) {
    const site = container.lookup("service:site");

    if (!site.composer_paused_workflows?.length) {
      return;
    }

    const composerPaused = container.lookup(
      "service:workflows-composer-paused"
    );

    container
      .lookup("service:app-events")
      .on(
        "composer:typing-paused",
        composerPaused,
        composerPaused.typingPaused
      );
  },
};
