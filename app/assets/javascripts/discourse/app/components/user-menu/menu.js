import GlimmerComponent from "discourse/components/glimmer";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import UserMenuTab from "discourse/lib/user-menu/tab";

const DEFAULT_TAB_ID = "all-notifications";
const DEFAULT_PANEL_COMPONENT = "user-menu/notifications-list";

const REVIEW_QUEUE_TAB_ID = "review-queue";

const CORE_TOP_TABS = [
  class extends UserMenuTab {
    get id() {
      return DEFAULT_TAB_ID;
    }

    get icon() {
      return "bell";
    }

    get panelComponent() {
      return DEFAULT_PANEL_COMPONENT;
    }
  },

  class extends UserMenuTab {
    get id() {
      return "replies";
    }

    get icon() {
      return "reply";
    }

    get panelComponent() {
      return "user-menu/replies-notifications-list";
    }
  },

  class extends UserMenuTab {
    get id() {
      return "mentions";
    }

    get icon() {
      return "at";
    }

    get panelComponent() {
      return "user-menu/mentions-notifications-list";
    }
  },

  class extends UserMenuTab {
    get id() {
      return "likes";
    }

    get icon() {
      return "heart";
    }

    get panelComponent() {
      return "user-menu/likes-notifications-list";
    }

    get shouldDisplay() {
      return !this.currentUser.likes_notifications_disabled;
    }
  },

  class extends UserMenuTab {
    get id() {
      return REVIEW_QUEUE_TAB_ID;
    }

    get icon() {
      return "flag";
    }

    get panelComponent() {
      return "user-menu/reviewables-list";
    }

    get shouldDisplay() {
      return this.currentUser.can_review;
    }

    get count() {
      return this.currentUser.get("reviewable_count");
    }
  },
];

export default class UserMenu extends GlimmerComponent {
  @tracked currentTabId = DEFAULT_TAB_ID;
  @tracked currentPanelComponent = DEFAULT_PANEL_COMPONENT;

  constructor() {
    super(...arguments);
    this.topTabs = this._topTabs;
    this.bottomTabs = this._bottomTabs;
  }

  get _topTabs() {
    const tabs = [];
    CORE_TOP_TABS.forEach((tabClass) => {
      const tab = new tabClass(this.currentUser, this.siteSettings, this.site);
      if (tab.shouldDisplay) {
        tabs.push(tab);
      }
    });
    return tabs.map((tab, index) => {
      tab.position = index;
      return tab;
    });
  }

  get _bottomTabs() {
    const topTabsLength = this.topTabs.length;
    return this._coreBottomTabs.map((tab, index) => {
      tab.position = index + topTabsLength;
      return tab;
    });
  }

  get _coreBottomTabs() {
    return [
      {
        id: "preferences",
        icon: "user-cog",
        href: `${this.currentUser.path}/preferences`,
      },
    ];
  }

  @action
  changeTab(tab) {
    if (this.currentTabId !== tab.id) {
      this.currentTabId = tab.id;
      this.currentPanelComponent = tab.panelComponent;
    }
  }

  @action
  triggerRenderedAppEvent() {
    this.appEvents.trigger("user-menu:rendered");
  }
}
