import { ajax } from "discourse/lib/ajax";
import { escapeExpression } from "discourse/lib/utilities";

export default createWidget("nft-card", {
  tagName: "div.nft-card",
  buildKey: (attrs) => `nft-card-${attrs.nft.contract_address}-${attrs.nft.token_id}`,

  defaultState() {
    return { liked: false, saved: false };
  },

  html(attrs, state) {
    const nft = attrs.nft;
    const { liked, saved } = state;

    return [
      h("div.nft-image-container", [
        h("img.nft-image", {
          attributes: {
            src: escapeExpression(nft.image_url),
            alt: escapeExpression(nft.title),
            loading: "lazy",
          },
        }),
        h("div.nft-overlay", [
          h("span.chain-badge", nft.metadata?.chain || "ETH"),
          nft.verified ? h("span.verified-badge", "✓ Verified") : null,
        ]),
      ]),
      h("div.nft-content", [
        h("h4.nft-name", nft.name || nft.title),
        h("p.nft-collection", nft.metadata?.collection_name || "Unknown Collection"),
        h("div.nft-price", [
          h("span.current-price", `${nft.current_price} ETH`),
          nft.discount_percentage > 0
            ? h("span.discount", `-${nft.discount_percentage}%`)
            : null,
        ]),
        h("div.nft-traits", this.renderTraits(nft.metadata?.traits)),
        h("div.nft-footer", [
          h(
            "a.view-on-opensea",
            {
              attributes: {
                href: escapeExpression(nft.external_url),
                target: "_blank",
                rel: "noopener noreferrer",
              },
            },
            "View on OpenSea"
          ),
          h(
            "button.like-btn",
            {
              className: liked ? "active" : "",
              click: () => this.toggleLike(nft),
            },
            `${liked ? "❤️" : "🤍"}`
          ),
        ]),
      ]),
    ];
  },

  renderTraits(traits) {
    if (!traits || traits.length === 0) return null;

    const displayTraits = traits.slice(0, 4);
    return h("div.traits-list", [
      ...displayTraits.map((trait) =>
        h("span.trait", [
          h("span.trait-type", trait.trait_type),
          h("span.trait-value", trait.value),
        ])
      ),
      traits.length > 4 ? h("span.more-traits", `+${traits.length - 4}`) : null,
    ]);
  },

  toggleLike(nft) {
    const action = this.state.liked ? "unlike" : "like";
    const method = this.state.liked ? "DELETE" : "POST";

    // For NFTs, we treat them as deals for liking
    if (nft.deal_id) {
      ajax(`/tangyzen/deals/${nft.deal_id}/${action}.json`, { method })
        .then((result) => {
          nft.like_count = result.like_count;
          this.state.liked = !this.state.liked;
          this.scheduleRerender();
        })
        .catch(() => {
          // Handle error silently
        });
    }
  },
});
