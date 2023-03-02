createWidget("search-menu-recent-searches", {
  tagName: "div.search-menu-recent",

  template: hbs`
    <div class="heading">
      <h4>{{i18n "search.recent"}}</h4>
      {{flat-button
        className="clear-recent-searches"
        title="search.clear_recent"
        icon="times"
        action="clearRecent"
      }}
    </div>

    {{#each this.currentUser.recent_searches as |slug|}}
      {{attach
        widget="search-menu-assistant-item"
        attrs=(hash slug=slug icon="history")
      }}
    {{/each}}
  `,

  clearRecent() {
    return User.resetRecentSearches().then((result) => {
      if (result.success) {
        this.currentUser.recent_searches.clear();
        this.sendWidgetAction("refreshSearchMenuResults");
      }
    });
  },
});
