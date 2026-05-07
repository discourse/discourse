import "ember-testing";
import { setEnvironment } from "discourse/lib/environment";
setEnvironment("qunit-testing");

import "discourse/loader";
import "discourse/discourse-common-loader-shims";
import "./set-test-env";
import { startTests } from "./test-boot-ember-cli";

const iframe = document.createElement("iframe");
iframe.style = "display: none;";
iframe.srcdoc = `<script type="module" src="${window._discourseQunitLiveReloadUrl}"></script>`;
document.body.append(iframe);

startTests();
