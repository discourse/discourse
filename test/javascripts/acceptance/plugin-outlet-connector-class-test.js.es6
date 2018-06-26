import { acceptance } from "helpers/qunit-helpers";
import { extraConnectorClass } from "discourse/lib/plugin-connectors";

const PREFIX = "javascripts/single-test/connectors";
acceptance("Plugin Outlet - Connector Class", {
  beforeEach() {
    extraConnectorClass("user-profile-primary/hello", {
      actions: {
        sayHello() {
          this.set("hello", "hello!");
        }
      }
    });

    extraConnectorClass("user-profile-primary/dont-render", {
      shouldRender(args) {
        return args.model.get("username") !== "eviltrout";
      }
    });

    Ember.TEMPLATES[
      `${PREFIX}/user-profile-primary/hello`
    ] = Ember.HTMLBars.compile(
      `<span class='hello-username'>{{model.username}}</span>
        <button class='say-hello' {{action "sayHello"}}></button>
        <span class='hello-result'>{{hello}}</span>`
    );
    Ember.TEMPLATES[
      `${PREFIX}/user-profile-primary/dont-render`
    ] = Ember.HTMLBars.compile(`I'm not rendered!`);
  },

  afterEach() {
    delete Ember.TEMPLATES[`${PREFIX}/user-profile-primary/hello`];
    delete Ember.TEMPLATES[`${PREFIX}/user-profile-primary/dont-render`];
  }
});

QUnit.test("Renders a template into the outlet", assert => {
  visit("/u/eviltrout");
  andThen(() => {
    assert.ok(
      find(".user-profile-primary-outlet.hello").length === 1,
      "it has class names"
    );
    assert.ok(
      !find(".user-profile-primary-outlet.dont-render").length,
      "doesn't render"
    );
  });
  click(".say-hello");
  andThen(() => {
    assert.equal(
      find(".hello-result").text(),
      "hello!",
      "actions delegate properly"
    );
  });
});
