import { ajax } from "discourse/lib/ajax";

export default createWidget("web3-dashboard", {
  tagName: "div.web3-dashboard",
  buildKey: () => "web3-dashboard",

  defaultState() {
    return {
      trending: [],
      myNfts: [],
      collections: [],
      walletConnected: false,
      walletAddress: null,
      loading: false,
      activeTab: "trending",
    };
  },

  didRender() {
    if (this.state.trending.length === 0 && !this.state.loading) {
      this.loadTrendingNFTs();
    }
  },

  html(attrs, state) {
    return [
      h("div.web3-header", [
        h("h2.title", "Web3 & NFT Hub"),
        h("div.wallet-section", [
          state.walletConnected
            ? [
                h("span.wallet-address", this.formatAddress(state.walletAddress)),
                h("button.disconnect-btn", "Disconnect", {
                  click: () => this.disconnectWallet(),
                }),
              ]
            : h("button.connect-btn", "Connect Wallet", {
                click: () => this.connectWallet(),
              }),
        ]),
      ]),
      h("div.web3-tabs", [
        h(
          "button.tab-btn",
          { className: state.activeTab === "trending" ? "active" : "" },
          {
            click: () => this.switchTab("trending"),
          },
          "🔥 Trending"
        ),
        h(
          "button.tab-btn",
          { className: state.activeTab === "collections" ? "active" : "" },
          {
            click: () => this.switchTab("collections"),
          },
          "📚 Collections"
        ),
        h(
          "button.tab-btn",
          { className: state.activeTab === "my-nfts" ? "active" : "" },
          {
            click: () => this.switchTab("my-nfts"),
          },
          "💎 My NFTs"
        ),
        h(
          "button.tab-btn",
          { className: state.activeTab === "search" ? "active" : "" },
          {
            click: () => this.switchTab("search"),
          },
          "🔍 Search"
        ),
      ]),
      h("div.web3-content", this.renderContent(state)),
      state.loading ? h("div.loading-spinner", "Loading...") : null,
    ];
  },

  renderContent(state) {
    switch (state.activeTab) {
      case "trending":
        return this.renderTrending(state.trending);
      case "collections":
        return this.renderCollections(state.collections);
      case "my-nfts":
        return this.renderMyNfts(state.myNfts);
      case "search":
        return this.renderSearch();
      default:
        return null;
    }
  },

  renderTrending(trending) {
    if (!trending || trending.length === 0) {
      return h("div.empty-state", "No trending NFTs available");
    }

    return h("div.trending-grid", [
      ...trending.slice(0, 12).map((collection) =>
        h("div.collection-card", [
          h("img.collection-img", {
            attributes: {
              src: collection.image_url,
              alt: collection.name,
            },
          }),
          h("h4.collection-name", collection.name),
          h("p.collection-stats", [
            h("span.floor-price", `Floor: ${collection.floor_price} ETH`),
            h("span.total-volume", `Volume: ${collection.total_volume} ETH`),
          ]),
        ])
      ),
    ]);
  },

  renderCollections(collections) {
    if (!collections || collections.length === 0) {
      return h("div.empty-state", "No collections available");
    }

    return h("div.collections-grid", [
      ...collections.map((collection) =>
        h("div.collection-card", [
          h("img.collection-img", {
            attributes: {
              src: collection.image_url,
              alt: collection.name,
            },
          }),
          h("h4.collection-name", collection.name),
          h("p.collection-description", collection.description),
        ])
      ),
    ]);
  },

  renderMyNfts(myNfts) {
    if (!this.state.walletConnected) {
      return h(
        "div.wallet-required",
        "Please connect your wallet to view your NFTs"
      );
    }

    if (!myNfts || myNfts.length === 0) {
      return h("div.empty-state", "You don't have any NFTs yet");
    }

    return h("div.nfts-grid", [
      ...myNfts.map((nft) => this.attach("nft-card", { nft })),
    ]);
  },

  renderSearch() {
    return h("div.search-container", [
      h("input.search-input", {
        type: "text",
        placeholder: "Search NFTs, collections...",
        keydown: (event) => {
          if (event.key === "Enter") {
            this.searchNfts(event.target.value);
          }
        },
      }),
      h("button.search-btn", "Search", {
        click: () => this.searchNfts(document.querySelector(".search-input").value),
      }),
    ]);
  },

  loadTrendingNFTs() {
    this.state.loading = true;
    this.scheduleRerender();

    ajax("/tangyzen/web3/trending.json")
      .then((result) => {
        this.state.trending = result.trending || [];
        this.state.loading = false;
        this.scheduleRerender();
      })
      .catch(() => {
        this.state.loading = false;
        this.scheduleRerender();
      });
  },

  loadCollections() {
    this.state.loading = true;
    this.scheduleRerender();

    ajax("/tangyzen/web3/collections.json")
      .then((result) => {
        this.state.collections = result.collections || [];
        this.state.loading = false;
        this.scheduleRerender();
      })
      .catch(() => {
        this.state.loading = false;
        this.scheduleRerender();
      });
  },

  loadMyNfts() {
    if (!this.state.walletConnected) return;

    this.state.loading = true;
    this.scheduleRerender();

    ajax("/tangyzen/web3/my_nfts.json")
      .then((result) => {
        this.state.myNfts = result.nfts || [];
        this.state.loading = false;
        this.scheduleRerender();
      })
      .catch(() => {
        this.state.loading = false;
        this.scheduleRerender();
      });
  },

  connectWallet() {
    // For now, we'll use a simple prompt
    // In production, integrate with MetaMask, WalletConnect, etc.
    const address = prompt("Enter your wallet address:");

    if (address && this.isValidAddress(address)) {
      ajax("/tangyzen/web3/connect_wallet.json", {
        type: "POST",
        data: { wallet_address: address },
      })
        .then((result) => {
          this.state.walletConnected = true;
          this.state.walletAddress = address;
          this.scheduleRerender();
        })
        .catch(() => {
          alert("Failed to connect wallet");
        });
    }
  },

  disconnectWallet() {
    ajax("/tangyzen/web3/disconnect_wallet.json", {
      type: "DELETE",
    })
      .then(() => {
        this.state.walletConnected = false;
        this.state.walletAddress = null;
        this.state.myNfts = [];
        this.scheduleRerender();
      })
      .catch(() => {
        alert("Failed to disconnect wallet");
      });
  },

  searchNfts(query) {
    if (!query || query.trim() === "") return;

    this.state.loading = true;
    this.scheduleRerender();

    ajax("/tangyzen/web3/search.json", {
      data: { q: query },
    })
      .then((result) => {
        this.state.searchResults = result.results || [];
        this.state.loading = false;
        this.renderSearchResults(this.state.searchResults);
      })
      .catch(() => {
        this.state.loading = false;
        this.scheduleRerender();
      });
  },

  renderSearchResults(results) {
    const contentArea = document.querySelector(".web3-content");
    contentArea.innerHTML = "";

    if (results.length === 0) {
      contentArea.innerHTML = '<div class="empty-state">No NFTs found</div>';
      return;
    }

    const grid = document.createElement("div");
    grid.className = "nfts-grid";
    results.forEach((nft) => {
      grid.appendChild(this.createNFTCardElement(nft));
    });
    contentArea.appendChild(grid);
  },

  createNFTCardElement(nft) {
    const card = document.createElement("div");
    card.className = "nft-card-preview";
    card.innerHTML = `
      <img src="${nft.image_url}" alt="${nft.title}" />
      <div class="nft-info">
        <h4>${nft.title}</h4>
        <p>Price: ${nft.current_price} ETH</p>
      </div>
    `;
    return card;
  },

  switchTab(tab) {
    this.state.activeTab = tab;

    switch (tab) {
      case "trending":
        if (this.state.trending.length === 0) {
          this.loadTrendingNFTs();
        }
        break;
      case "collections":
        if (this.state.collections.length === 0) {
          this.loadCollections();
        }
        break;
      case "my-nfts":
        this.loadMyNfts();
        break;
    }

    this.scheduleRerender();
  },

  formatAddress(address) {
    return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
  },

  isValidAddress(address) {
    return /^0x[a-fA-F0-9]{40}$/.test(address);
  },
});
