import { createWidget } from "discourse/widgets/widget";
import deprecated from "discourse-common/lib/deprecated";

deprecated(
  "widgets/default-notification-item was imported, but the widget-based notification menu has been removed.",
  { id: "discourse.default-notification-item" }
);

export const DefaultNotificationItem = createWidget(
  "default-notification-item",
  {}
);
