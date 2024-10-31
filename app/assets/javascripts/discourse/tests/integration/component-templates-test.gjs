import Component from "@glimmer/component";
import { setComponentTemplate } from "@glimmer/manager";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { assert, module, test } from "qunit";
import sinon from "sinon";
import { overrideThrowGjsError } from "discourse/instance-initializers/component-templates";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { withSilencedDeprecationsAsync } from "discourse-common/lib/deprecated";
import { registerTemporaryModule } from "../helpers/temporary-module-helper";

function silenceMobileDeprecations(hooks) {
  let unsilenceCallback;
  hooks.beforeEach(() => {
    const promise = new Promise((resolve) => (unsilenceCallback = resolve));
    withSilencedDeprecationsAsync(
      ["discourse.mobile-templates"],
      () => promise
    );
  });
  hooks.afterEach(() => unsilenceCallback());
}

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
class MockColocatedComponent extends Component {}
setComponentTemplate(hbs`Colocated Original`, MockColocatedComponent);

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
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

function registerTemplateOnlyComponents() {
  registerTemporaryModule(
    `discourse/templates/components/core-template-only-definition`,
    hbs`glimmer template-only component`
  );

  registerTemporaryModule(
    `discourse/plugins/some-plugin-name/discourse/templates/components/plugin-template-only-definition`,
    hbs`classic component`
  );
}

module("Integration | Initializers | plugin-component-templates", function (h) {
  silenceMobileDeprecations(h);

  module("template-only component definition behaviour", function (hooks) {
    hooks.beforeEach(() => registerTemplateOnlyComponents());
    setupRenderingTest(hooks);

    test("treats plugin template-only definition as classic component", async function () {
      await render(hbs`<PluginTemplateOnlyDefinition class='test-class'/>`);
      assert
        .dom("div.test-class")
        .hasText("classic component", "renders as classic component");
    });

    test("leaves core template-only definition as glimmer template-only component", async function () {
      await render(hbs`<CoreTemplateOnlyDefinition class='test-class'/>`);
      assert
        .dom("div.test-class")
        .doesNotExist("no classic component rendered");
      assert.dom().hasText("glimmer template-only component");
    });
  });

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
    hooks.beforeEach(() => registerBaseComponents());
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

  module("overriding gjs component", function (hooks) {
    let errorStub;

    hooks.beforeEach(() => {
      registerTemporaryModule(
        `discourse/components/mock-gjs-component`,
        class MyComponent extends Component {
          <template>
            <span class="greeting">Hello world</span>
          </template>
        }
      );

      registerTemporaryModule(
        `discourse/plugins/my-plugin/discourse/templates/components/mock-gjs-component`,
        hbs`doomed override`
      );

      errorStub = sinon
        .stub(console, "error")
        .withArgs(sinon.match(/mock-gjs-component was authored using gjs/));

      overrideThrowGjsError(false);
    });

    hooks.afterEach(() => {
      overrideThrowGjsError(true);
    });

    setupRenderingTest(hooks);

    test("theme overrides plugin component", async function () {
      await render(hbs`<MockGjsComponent />`);
      assert
        .dom(".greeting")
        .hasText("Hello world", "renders original implementation");

      sinon.assert.calledOnce(errorStub);
    });
  });
});
