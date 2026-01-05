import { ajax } from "discourse/lib/ajax";
import { escapeExpression } from "discourse/lib/utilities";

export default createWidget("gaming-card", {
  tagName: "div.gaming-card",
  buildKey: (attrs) => `gaming-card-${attrs.gaming.id}`,

  defaultState() {
    return { liked: false, saved: false };
  },

  html(attrs, state) {
    const gaming = attrs.gaming;
    const { liked, saved } = state;

    return [
      h("div.gaming-cover", {
        attributes: {
          style: `background-image: url('${escapeExpression(gaming.cover_image_url)}')`,
        },
      }),
      h("div.gaming-content", [
        h("span.genre-badge", gaming.genre),
        h("h3.gaming-title", gaming.game_name),
        h("p.gaming-description", gaming.description),
        h("div.gaming-info", [
          h("span.platform", this.iconHtml(gaming.platform)),
          h("span.developer", gaming.developer),
          gaming.rating
            ? h("span.rating", `${"⭐".repeat(Math.round(gaming.rating))} ${gaming.rating}`)
            : null,
          gaming.playtime_hours
            ? h("span.playtime", `${gaming.playtime_hours}h playtime`)
            : null,
        ]),
        h("div.gaming-badges", [
          gaming.multiplayer ? h("span.badge.multiplayer", "Multiplayer") : null,
          gaming.coop ? h("span.badge.coop", "Co-op") : null,
          gaming.cross_platform ? h("span.badge.cross-platform", "Cross-platform") : null,
          gaming.free_to_play ? h("span.badge.free", "Free") : null,
          gaming.dlc_available ? h("span.badge.dlc", "DLC Available") : null,
        ]),
        h("div.gaming-footer", [
          h(
            "button.like-btn",
            {
              className: liked ? "active" : "",
              click: () => this.toggleLike(gaming),
            },
            `${liked ? "❤️" : "🤍"} ${gaming.like_count}`
          ),
          h(
            "button.save-btn",
            {
              className: saved ? "active" : "",
              click: () => this.toggleSave(gaming),
            },
            `${saved ? "🔖" : "📌"} ${gaming.save_count}`
          ),
          h("span.views", `👁️ ${gaming.view_count}`),
        ]),
      ]),
    ];
  },

  iconHtml(platform) {
    const icons = {
      PC: "💻",
      PlayStation: "🎮",
      Xbox: "🎯",
      Nintendo: "🔴",
      iOS: "📱",
      Android: "🤖",
      Switch: "🔀",
    };
    return icons[platform] || "🎮";
  },

  toggleLike(gaming) {
    const action = this.state.liked ? "unlike" : "like";
    const method = this.state.liked ? "DELETE" : "POST";

    ajax(`/tangyzen/gaming/${gaming.id}/${action}.json`, { method })
      .then((result) => {
        gaming.like_count = result.like_count;
        this.state.liked = !this.state.liked;
        this.scheduleRerender();
      })
      .catch(() => {
        // Handle error silently
      });
  },

  toggleSave(gaming) {
    const action = this.state.saved ? "unsave" : "save";
    const method = this.state.saved ? "DELETE" : "POST";

    ajax(`/tangyzen/gaming/${gaming.id}/${action}.json`, { method })
      .then((result) => {
        gaming.save_count = result.save_count;
        this.state.saved = !this.state.saved;
        this.scheduleRerender();
      })
      .catch(() => {
        // Handle error silently
      });
  },
});
