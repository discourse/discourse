import { ForesightManager } from "js.foresight";

export default {
  after: "inject-discourse-objects",

  initialize() {
    ForesightManager.initialize({
      enableMousePrediction: true,
      positionHistorySize: 8,
      trajectoryPredictionTime: 80,
      defaultHitSlop: 10,
      debug: false,
      debuggerSettings: {
        isControlPanelDefaultMinimized: true,
        showNameTags: false,
      },
      enableTabPrediction: true,
      tabOffset: 3,
      onAnyCallbackFired: (_elementData, managerData) => {
        // eslint-disable-next-line no-console
        console.log(`Total tab hits: ${managerData.globalCallbackHits.tab}`);
        // eslint-disable-next-line no-console
        console.log(`total mouse hits ${managerData.globalCallbackHits.mouse}`);
      },
    });
  },
};
