import "ember-testing";
import { setEnvironment } from "discourse/lib/environment";
setEnvironment("qunit-testing");

import "discourse/loader";
import "discourse/discourse-common-loader-shims";
import "./set-test-env.js";
import { startTests } from "./test-boot-ember-cli.js";

startTests();
