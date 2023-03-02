
createWidget("random-quick-tip", {
  tagName: "li.search-random-quick-tip",

  buildKey: () => "random-quick-tip",

  defaultState() {
    return QUICK_TIPS[Math.floor(Math.random() * QUICK_TIPS.length)];
  },

  html(attrs, state) {
    return [
      h(
        `span.tip-label${state.clickable ? ".tip-clickable" : ""}`,
        state.label
      ),
      h("span.tip-description", state.description),
    ];
  },

  click(e) {
    if (e.target.classList.contains("tip-clickable")) {
      const searchInput = document.querySelector("#search-term");
      searchInput.value = this.state.label;
      searchInput.focus();
      this.sendWidgetAction("triggerAutocomplete", {
        value: this.state.label,
        searchTopics: this.state.searchTopics,
      });
    }
  },
});
