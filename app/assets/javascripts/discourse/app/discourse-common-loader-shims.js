import { importSync } from "@embroider/macros";
import loaderShim from "discourse/lib/loader-shim";

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

loaderShim("discourse-common/lib/attribute-hook", () =>
  importSync("discourse/lib/attribute-hook")
);
loaderShim("discourse-common/lib/avatar-utils", () =>
  importSync("discourse/lib/avatar-utils")
);
loaderShim("discourse-common/lib/case-converter", () =>
  importSync("discourse/lib/case-converter")
);
loaderShim("discourse-common/lib/debounce", () =>
  importSync("discourse/lib/debounce")
);
loaderShim("discourse-common/lib/deprecated", () =>
  importSync("discourse/lib/deprecated")
);
loaderShim("discourse-common/lib/discourse-template-map", () =>
  importSync("discourse/lib/discourse-template-map")
);
loaderShim("discourse-common/lib/dom-from-string", () =>
  importSync("discourse/lib/dom-from-string")
);
loaderShim("discourse-common/lib/escape", () =>
  importSync("discourse/lib/escape")
);
loaderShim("discourse-common/lib/get-owner", () =>
  importSync("discourse/lib/get-owner")
);
loaderShim("discourse-common/lib/get-url", () =>
  importSync("discourse/lib/get-url")
);
loaderShim("discourse-common/lib/helpers", () =>
  importSync("discourse/lib/helpers")
);
loaderShim("discourse-common/lib/icon-library", () =>
  importSync("discourse/lib/icon-library")
);
loaderShim("discourse-common/lib/later", () =>
  importSync("discourse/lib/later")
);
loaderShim("discourse-common/lib/loader-shim", () =>
  importSync("discourse/lib/loader-shim")
);
loaderShim("discourse-common/lib/object", () =>
  importSync("discourse/lib/object")
);
loaderShim("discourse-common/lib/popular-themes", () =>
  importSync("discourse/lib/popular-themes")
);
loaderShim("discourse-common/lib/raw-handlebars-helpers", () =>
  importSync("discourse/lib/raw-handlebars-helpers")
);
loaderShim("discourse-common/lib/raw-handlebars", () =>
  importSync("discourse/lib/raw-handlebars")
);
loaderShim("discourse-common/lib/raw-templates", () =>
  importSync("discourse/lib/raw-templates")
);
loaderShim("discourse-common/lib/suffix-trie", () =>
  importSync("discourse/lib/suffix-trie")
);

loaderShim("discourse-common/utils/decorator-alias", () =>
  importSync("discourse/lib/decorator-alias")
);
loaderShim("discourse-common/utils/decorators", () =>
  importSync("discourse/lib/decorators")
);
loaderShim("discourse-common/utils/dom-utils", () =>
  importSync("discourse/lib/dom-utils")
);
loaderShim("discourse-common/utils/escape-regexp", () =>
  importSync("discourse/lib/escape-regexp")
);
loaderShim("discourse-common/utils/extract-value", () =>
  importSync("discourse/lib/extract-value")
);
loaderShim("discourse-common/utils/handle-descriptor", () =>
  importSync("discourse/lib/handle-descriptor")
);
loaderShim("discourse-common/utils/is-descriptor", () =>
  importSync("discourse/lib/is-descriptor")
);
loaderShim("discourse-common/utils/macro-alias", () =>
  importSync("discourse/lib/macro-alias")
);
loaderShim("discourse-common/utils/multi-cache", () =>
  importSync("discourse/lib/multi-cache")
);

loaderShim("discourse-common/resolver", () => importSync("discourse/resolver"));
