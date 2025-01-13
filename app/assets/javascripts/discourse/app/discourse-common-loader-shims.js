import { importSync } from "@embroider/macros";
import loaderShim from "discourse-common/lib/loader-shim";

// Soon-to-be-deprecated discourse-common imports
loaderShim("discourse-common/helpers/base-path", () =>
  importSync("discourse/helpers/base-path")
);
loaderShim("discourse-common/helpers/base-url", () =>
  importSync("discourse/helpers/base-url")
);
loaderShim("discourse-common/helpers/bound-i18n", () =>
  importSync("discourse/helpers/bound-i18n")
);
loaderShim("discourse-common/helpers/component-for-collection", () =>
  importSync("discourse/helpers/component-for-collection")
);
loaderShim("discourse-common/helpers/component-for-row", () =>
  importSync("discourse/helpers/component-for-row")
);
loaderShim("discourse-common/helpers/d-icon", () =>
  importSync("discourse/helpers/d-icon")
);
loaderShim("discourse-common/helpers/fa-icon", () =>
  importSync("discourse/helpers/fa-icon")
);
loaderShim("discourse-common/helpers/get-url", () =>
  importSync("discourse/helpers/get-url")
);
loaderShim("discourse-common/helpers/html-safe", () =>
  importSync("discourse/helpers/html-safe")
);
loaderShim("discourse-common/helpers/i18n-yes-no", () =>
  importSync("discourse/helpers/i18n-yes-no")
);
loaderShim("discourse-common/helpers/i18n", () =>
  importSync("discourse/helpers/i18n")
);
