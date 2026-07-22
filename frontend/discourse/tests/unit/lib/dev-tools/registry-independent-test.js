import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  clearDevTools,
  devToolsDAG,
  LAST_CORE_TOOL,
} from "discourse/lib/dev-tools/registry";
import devToolsState from "discourse/static/dev-tools/state";

const CORE_TOOL_IDS = [
  "plugin-outlet-debug",
  "block-debug",
  "upcoming-changes-debug",
  "safe-mode",
  "verbose-localization",
  LAST_CORE_TOOL,
];
const STORAGE_KEY = "discourse__dev_tools_state";
const TEST_TOOL_ID = "independent-state-tool";

function registerCoreTools(registry, componentFor = (id) => id) {
  let previous;

  for (const id of CORE_TOOL_IDS) {
    registry.add(id, componentFor(id), previous ? { after: previous } : {});
    previous = id;
  }
}

module("Unit | Lib | dev-tools | registry independent", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    clearDevTools();
  });

  test("registrations made before late core seeding survive without disturbing core order", function (assert) {
    const registry = devToolsDAG();
    const defaultPluginComponent = {};
    const positionedPluginComponent = {};

    registry.add("plugin-default", defaultPluginComponent);
    registry.add("plugin-before-block", positionedPluginComponent, {
      before: "block-debug",
    });
    registerCoreTools(registry);

    const resolved = registry.resolve();
    const resolvedKeys = resolved.map(({ key }) => key);

    assert.deepEqual(
      resolvedKeys.filter((key) => CORE_TOOL_IDS.includes(key)),
      CORE_TOOL_IDS,
      "late core registrations retain their required relative order"
    );
    assert.true(
      resolvedKeys.includes("plugin-default"),
      "a default-positioned early plugin registration survives"
    );
    assert.true(
      resolvedKeys.includes("plugin-before-block"),
      "an explicitly positioned early plugin registration survives"
    );
    assert.true(
      resolvedKeys.indexOf("plugin-default") >
        resolvedKeys.indexOf(LAST_CORE_TOOL),
      "the unresolved default anchor places the plugin after all core tools once seeded"
    );
    assert.true(
      resolvedKeys.indexOf("plugin-before-block") <
        resolvedKeys.indexOf("block-debug"),
      "an early constraint against a not-yet-registered core tool is honored"
    );
  });

  test("repeating core seeding is a no-op and does not erase plugin entries", function (assert) {
    const registry = devToolsDAG();
    const originalComponents = new Map(
      CORE_TOOL_IDS.map((id) => [id, { source: `original-${id}` }])
    );

    registry.add("plugin-tool", { source: "plugin" });
    registerCoreTools(registry, (id) => originalComponents.get(id));
    registerCoreTools(registry, (id) => ({ source: `replacement-${id}` }));

    const resolved = registry.resolve();

    assert.deepEqual(
      resolved.map(({ key }) => key),
      [...CORE_TOOL_IDS, "plugin-tool"],
      "idempotent seeding neither duplicates core entries nor removes the plugin"
    );

    for (const id of CORE_TOOL_IDS) {
      assert.strictEqual(
        resolved.find(({ key }) => key === id).value,
        originalComponents.get(id),
        `${id} keeps the component from the first seed`
      );
    }
  });
});

module("Unit | Lib | dev-tools | state independent", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.originalStorage = window.sessionStorage.getItem(STORAGE_KEY);
    this.originalBuiltInState = {
      pluginOutletDebug: devToolsState.pluginOutletDebug,
      blockDebug: devToolsState.blockDebug,
      blockVisualOverlay: devToolsState.blockVisualOverlay,
      blockGhostBlocks: devToolsState.blockGhostBlocks,
      blockOutletBoundaries: devToolsState.blockOutletBoundaries,
    };
    this.originalFlag = devToolsState.getFlag(TEST_TOOL_ID, "enabled");
  });

  hooks.afterEach(function () {
    Object.assign(devToolsState, this.originalBuiltInState);
    devToolsState.setFlag(TEST_TOOL_ID, "enabled", this.originalFlag);

    if (this.originalStorage === null) {
      window.sessionStorage.removeItem(STORAGE_KEY);
    } else {
      window.sessionStorage.setItem(STORAGE_KEY, this.originalStorage);
    }
  });

  test("the singleton rejects ad-hoc tool properties", function (assert) {
    assert.false(
      Object.isExtensible(devToolsState),
      "the shared state object is not extensible"
    );
    assert.throws(
      () => (devToolsState.independentAdHocFlag = true),
      TypeError,
      "a tool cannot bypass the nested flag API"
    );
  });

  test("a per-tool flag persists without clobbering built-in flags", function (assert) {
    const expectedBuiltIns = {
      pluginOutletDebug: true,
      blockDebug: false,
      blockVisualOverlay: true,
      blockGhostBlocks: false,
      blockOutletBoundaries: true,
    };

    Object.assign(devToolsState, expectedBuiltIns);
    devToolsState.setFlag(TEST_TOOL_ID, "enabled", "independent-value");

    const persisted = JSON.parse(window.sessionStorage.getItem(STORAGE_KEY));

    assert.strictEqual(
      devToolsState.getFlag(TEST_TOOL_ID, "enabled"),
      "independent-value",
      "the flag can be read through the public API"
    );
    assert.deepEqual(
      {
        pluginOutletDebug: persisted.pluginOutletDebug,
        blockDebug: persisted.blockDebug,
        blockVisualOverlay: persisted.blockVisualOverlay,
        blockGhostBlocks: persisted.blockGhostBlocks,
        blockOutletBoundaries: persisted.blockOutletBoundaries,
      },
      expectedBuiltIns,
      "all five built-in values remain in the persisted blob"
    );
    assert.deepEqual(
      persisted.flags[TEST_TOOL_ID],
      { enabled: "independent-value" },
      "the registered tool receives an isolated nested state bag"
    );
  });
});
