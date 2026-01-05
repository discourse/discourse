import { ajax } from "discourse/lib/ajax";
import { escapeExpression } from "discourse/lib/utilities";

export default createWidget("content-hub", {
  tagName: "div.content-hub",
  buildKey: () => "content-hub",

  defaultState() {
    return {
      activeTab: "gaming",
      content: {
        gaming: [],
        music: [],
        movies: [],
        reviews: [],
        arts: [],
        blogs: []
      },
      loading: false,
      filters: {
        sort: "trending",
        limit: 20
      }
    };
  },

  didRender() {
    if (this.state.content[this.state.activeTab].length === 0 && !this.state.loading) {
      this.loadContent(this.state.activeTab);
    }
  },

  html(attrs, state) {
    const { activeTab, content, loading, filters } = state;

    return [
      h("div.content-hub-header", [
        h("h1.title", "Content Hub"),
        h("div.header-actions", [
          h("div.sort-filters", [
            h("button.filter-btn", {
              className: filters.sort === "trending" ? "active" : "",
              click: () => this.setSort("trending")
            }, "🔥 Trending"),
            h("button.filter-btn", {
              className: filters.sort === "latest" ? "active" : "",
              click: () => this.setSort("latest")
            }, "🕐 Latest"),
            h("button.filter-btn", {
              className: filters.sort === "featured" ? "active" : "",
              click: () => this.setSort("featured")
            }, "⭐ Featured")
          ])
        ])
      }),
      h("div.content-tabs", this.renderTabs(activeTab)),
      h("div.content-grid", this.renderContentGrid(activeTab, content[activeTab], loading)),
      loading ? h("div.loading-spinner", "Loading...") : null
    ];
  },

  renderTabs(activeTab) {
    const tabs = [
      { id: "gaming", label: "🎮 Gaming" },
      { id: "music", label: "🎵 Music" },
      { id: "movies", label: "🍿 Movies" },
      { id: "reviews", label: "⚖️ Reviews" },
      { id: "arts", label: "📸 Arts" },
      { id: "blogs", label: "✍️ Blogs" }
    ];

    return tabs.map(tab =>
      h("button.tab-btn", {
        className: activeTab === tab.id ? "active" : "",
        click: () => this.switchTab(tab.id)
      }, tab.label)
    );
  },

  renderContentGrid(type, items, loading) {
    if (loading && items.length === 0) {
      return h("div.empty-state", "Loading content...");
    }

    if (!items || items.length === 0) {
      return h("div.empty-state", [
        h("div.empty-icon", "📭"),
        h("p", `No ${type} content found`),
        h("p.hint", "Be the first to share!")
      ]);
    }

    return h("div.grid-container", items.map(item => this.renderContentItem(type, item)));
  },

  renderContentItem(type, item) {
    switch (type) {
      case "gaming":
        return this.attach("gaming-card", { gaming: item });
      case "music":
        return this.renderMusicCard(item);
      case "movies":
        return this.renderMovieCard(item);
      case "reviews":
        return this.renderReviewCard(item);
      case "arts":
        return this.renderArtCard(item);
      case "blogs":
        return this.renderBlogCard(item);
      default:
        return null;
    }
  },

  switchTab(tabId) {
    this.state.activeTab = tabId;
    if (this.state.content[tabId].length === 0) {
      this.loadContent(tabId);
    }
    this.scheduleRerender();
  },

  setSort(sort) {
    this.state.filters.sort = sort;
    this.state.content[this.state.activeTab] = [];
    this.loadContent(this.state.activeTab);
  },

  loadContent(type) {
    this.state.loading = true;
    this.scheduleRerender();

    const endpoint = this.state.filters.sort === "featured" 
      ? `/tangyzen/${type}/featured.json`
      : `/tangyzen/${type}.json`;

    ajax(endpoint)
      .then(result => {
        const dataKey = this.getDataKey(result, type);
        this.state.content[type] = result[dataKey] || result[`${type}s`] || [];
        this.state.loading = false;
        this.scheduleRerender();
      })
      .catch(() => {
        this.state.loading = false;
        this.scheduleRerender();
      });
  },

  getDataKey(result, type) {
    const keys = Object.keys(result);
    return keys.find(k => k.includes(type) || k.includes(type + "s")) || type;
  }
});
