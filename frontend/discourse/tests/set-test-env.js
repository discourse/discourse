import deprecationWorkflow from "discourse/deprecation-workflow";
import * as environment from "discourse/lib/environment";

environment.setEnvironment("qunit-testing");
deprecationWorkflow.setEnvironment(environment);
