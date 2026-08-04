import "./styles.css";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import { patchBlockRendering } from "./block-debug/patch";
import { registerDockPanel } from "./dock";
import { install as observeMessageBus } from "./message-bus/instrumentation";
import MessageBusPanel from "./message-bus/panel";
import { patchConnectors } from "./plugin-outlet-debug/patch";
import Toolbar from "./toolbar";

export function init() {
  registerDockPanel("message-bus", {
    label: i18n("dev_tools.message_bus.title"),
    component: MessageBusPanel,
  });

  // Installed at load rather than when the panel is opened, so that the
  // subscriptions made during boot are attributed like any other.
  observeMessageBus();

  patchConnectors();
  patchBlockRendering();

  // TODO(devxp-typescript-pending): `plugin-api` is untyped JavaScript and does
  // not export the type of the API object, so only the member used here is
  // described. Drop this once the plugin API is authored in TypeScript.
  withPluginApi(
    (api: { renderInOutlet: (name: string, component: unknown) => void }) => {
      api.renderInOutlet("above-site-header", Toolbar);
    }
  );
}
