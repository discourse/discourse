import { assert, module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { registerTemporaryModule } from "../helpers/temporary-module-helper";
import { setComponentTemplate } from "@glimmer/manager";
import Component from "@glimmer/component";
import { forceMobile, resetMobile } from "discourse/lib/mobile";

class MockColocatedComponent extends Component {}
setComponentTemplate(hbs`Colocated Original`, MockColocatedComponent);

class MockResolvedComponent extends Component {}
const MockResolvedComponentTemplate = hbs`Resolved Original`;

const TestTemplate = hbs`
  <div id='mock-colocated'><MockColocated /></div>
  <div id='mock-resolved'><MockResolved /></div>
`;

function registerBaseComponents(namespace = "discourse") {
  registerTemporaryModule(
    `${namespace}/components/mock-colocated`,
    MockColocatedComponent
  );
  registerTemporaryModule(
    `${namespace}/templates/mobile/components/mock-colocated`,
    hbs`Core mobile template`
  );
  registerTemporaryModule(
    `${namespace}/components/mock-resolved`,
    MockResolvedComponent
  );
  registerTemporaryModule(
    `${namespace}/templates/components/mock-resolved`,
    MockResolvedComponentTemplate
  );
  registerTemporaryModule(
    `${namespace}/templates/mobile/components/mock-resolved`,
    hbs`Core resolved mobile`
  );
}

function registerThemeOverrides() {
  registerTemporaryModule(
    "discourse/theme-12/discourse/templates/components/mock-colocated",
    hbs`Colocated Theme Override`
  );
  registerTemporaryModule(
    `discourse/theme-12/discourse/templates/mobile/components/mock-colocated`,
    hbs`Colocated Mobile Theme Override`
  );
  registerTemporaryModule(
    "discourse/theme-12/discourse/templates/components/mock-resolved",
    hbs`Resolved Theme Override`
  );
  registerTemporaryModule(
    "discourse/theme-12/discourse/templates/mobile/components/mock-resolved",
    hbs`Resolved Mobile Theme Override`
  );
}

function registerPluginOverrides() {
  registerTemporaryModule(
    `discourse/plugins/some-plugin-name/discourse/templates/components/mock-colocated`,
    hbs`Colocated Plugin Override`
  );
  registerTemporaryModule(
    `discourse/plugins/some-plugin-name/discourse/templates/components/mock-resolved`,
    hbs`Resolved Plugin Override`
  );
}

function registerOtherPluginOverrides() {
  registerTemporaryModule(
    `discourse/plugins/other-plugin-name/discourse/templates/components/mock-colocated`,
    hbs`Colocated Other Plugin Override`
  );
  registerTemporaryModule(
    `discourse/plugins/other-plugin-name/discourse/templates/components/mock-resolved`,
    hbs`Resolved Other Plugin Override`
  );
}

module("Integration | Initializers | template-overrides", function () {
  module("with no overrides", function (hooks) {
    hooks.beforeEach(() => registerBaseComponents());
    setupRenderingTest(hooks);

    test("renders core templates when there are no overrides", async function () {
      await render(TestTemplate);
      assert
        .dom("#mock-colocated")
        .hasText("Colocated Original", "colocated component correct");
      assert
        .dom("#mock-resolved")
        .hasText("Resolved Original", "resolved component correct");
    });
  });

  module("with core mobile overrides", function (hooks) {
    hooks.beforeEach(() => {
      registerBaseComponents();
      forceMobile();
    });
    hooks.afterEach(resetMobile);

    setupRenderingTest(hooks);

    test("core mobile overrides are used", async function () {
      await render(TestTemplate);
      assert
        .dom("#mock-colocated")
        .hasText("Core mobile template", "colocated component correct");
      assert
        .dom("#mock-resolved")
        .hasText("Core resolved mobile", "resolved component correct");
    });
  });

  module("with theme overrides", function (hooks) {
    hooks.beforeEach(() => registerBaseComponents());
    hooks.beforeEach(registerThemeOverrides);
    setupRenderingTest(hooks);

    test("theme overrides are used", async function () {
      await render(TestTemplate);
      assert
        .dom("#mock-colocated")
        .hasText("Colocated Theme Override", "colocated component correct");
      assert
        .dom("#mock-resolved")
        .hasText("Resolved Theme Override", "resolved component correct");
    });
  });

  module("with mobile theme overrides", function (hooks) {
    hooks.beforeEach(() => {
      registerThemeOverrides();
      forceMobile();
      registerBaseComponents();
    });
    hooks.afterEach(resetMobile);

    setupRenderingTest(hooks);

    test("mobile theme overrides are used", async function () {
      await render(TestTemplate);
      assert
        .dom("#mock-colocated")
        .hasText(
          "Colocated Mobile Theme Override",
          "colocated component correct"
        );
      assert
        .dom("#mock-resolved")
        .hasText(
          "Resolved Mobile Theme Override",
          "resolved component correct"
        );
    });
  });

  module("with plugin overrides", function (hooks) {
    hooks.beforeEach(() => registerBaseComponents());
    hooks.beforeEach(registerPluginOverrides);
    setupRenderingTest(hooks);

    test("plugin overrides are used", async function () {
      await render(TestTemplate);
      assert
        .dom("#mock-colocated")
        .hasText("Colocated Plugin Override", "colocated component correct");
      assert
        .dom("#mock-resolved")
        .hasText("Resolved Plugin Override", "resolved component correct");
    });
  });

  module("with theme and plugin overrides", function (hooks) {
    hooks.beforeEach(registerPluginOverrides);
    hooks.beforeEach(registerThemeOverrides);
    setupRenderingTest(hooks);

    test("plugin overrides are used", async function () {
      await render(TestTemplate);
      assert
        .dom("#mock-colocated")
        .hasText("Colocated Theme Override", "colocated component correct");
      assert
        .dom("#mock-resolved")
        .hasText("Resolved Theme Override", "resolved component correct");
    });
  });

  module("with multiple plugin overrides", function (hooks) {
    hooks.beforeEach(() => registerBaseComponents());
    hooks.beforeEach(registerPluginOverrides);
    hooks.beforeEach(registerOtherPluginOverrides);
    setupRenderingTest(hooks);

    test("last-defined plugin overrides are used", async function () {
      await render(TestTemplate);
      assert
        .dom("#mock-colocated")
        .hasText(
          "Colocated Other Plugin Override",
          "colocated component correct"
        );
      assert
        .dom("#mock-resolved")
        .hasText(
          "Resolved Other Plugin Override",
          "resolved component correct"
        );
    });
  });

  module("theme overriding plugin", function (hooks) {
    hooks.beforeEach(() =>
      registerBaseComponents("discourse/plugins/base-plugin/discourse")
    );
    hooks.beforeEach(registerThemeOverrides);
    setupRenderingTest(hooks);

    test("theme overrides plugin component", async function () {
      await render(TestTemplate);
      assert
        .dom("#mock-colocated")
        .hasText("Colocated Theme Override", "colocated component correct");
      assert
        .dom("#mock-resolved")
        .hasText("Resolved Theme Override", "resolved component correct");
    });
  });
});
