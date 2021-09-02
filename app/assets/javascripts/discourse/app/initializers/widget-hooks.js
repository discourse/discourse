import { WidgetClickHook } from "discourse/widgets/hooks";

export default {
  name: "widget-hooks",

  initialize() {
    WidgetClickHook.setupDocumentCallback();
  },

  teardown() {
    WidgetClickHook.teardownDocumentCallback();
  },
};
