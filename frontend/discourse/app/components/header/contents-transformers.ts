import type Topic from "discourse/models/topic";

/** Contract for the `home-logo-minimized` value transformer. */
export interface HomeLogoMinimizedTransformer {
  value: boolean;
  context: {
    /** Null when no topic page is open. */
    topicInfo: Topic | null;
    sidebarEnabled: boolean;
    showSidebar: boolean;
  };
  mutable: false;
}
