import { parseAst as parse } from "rolldown/parseAst";
import { describe, expect, it } from "vitest";
import {
  buildRouteTree,
  bundleByRouteFor,
  deriveRoutes,
  parseRouteMap,
  urlTableFor,
} from "./route-map-parser";

function read(source, opts = {}) {
  return parseRouteMap(parse(source), {
    filename: "test-route-map.js",
    source,
    label: "PLUGIN test",
    ...opts,
  });
}

// `core: true` stands in for core's own maps, whose routes get no implicit bundle.
function tablesFor(sources) {
  const maps = sources.map((source) =>
    typeof source === "string"
      ? read(source)
      : { core: source.core, ...read(source.source, source) }
  );
  const derived = deriveRoutes(buildRouteTree(maps).root);

  return {
    bundleByRoute: bundleByRouteFor(derived),
    urls: urlTableFor(derived),
  };
}

describe("parseRouteMap", () => {
  it("reads a function map", () => {
    const map = read(`export default function () {
      this.route("chat", { bundleName: "chat" }, function () {
        this.route("channel", { path: "/c/:channelTitle/:channelId" });
      });
    }`);

    expect(map.resource).toBe(null);
    expect(map.routes[0].name).toBe("chat");
    expect(map.routes[0].options).toEqual({ bundleName: "chat" });
    expect(map.routes[0].children[0].options).toEqual({
      path: "/c/:channelTitle/:channelId",
    });
  });

  it("reads a resource map, ignoring `path` the router ignores", () => {
    const map = read(`export default {
      resource: "admin.adminPlugins.show",
      path: "/plugins",
      map() {
        this.route("hooks");
      },
    };`);

    expect(map.resource).toBe("admin.adminPlugins.show");
    expect(map.routes).toHaveLength(1);
  });

  it.each([
    [
      "a loop",
      `export default function () { for (const x of []) { this.route(x); } }`,
    ],
    [
      "a conditional",
      `export default function () { if (window.x) { this.route("a"); } }`,
    ],
    ["a computed name", `export default function () { this.route(NAME); }`],
    [
      "a spread",
      `export default function () { this.route("a", { ...opts }); }`,
    ],
    [
      "a non-literal option",
      `export default function () { this.route("a", { path: X }); }`,
    ],
    ["another call", `export default function () { setup(); }`],
    [
      "an arrow callback",
      `export default function () { this.route("a", () => {}); }`,
    ],
    ["no default export", `export function map() {}`],
    [
      "a `map` reference",
      `export default { resource: "a", map: someFunction };`,
    ],
  ])("rejects %s", (_label, source) => {
    expect(() => read(source)).toThrow(/test-route-map\.js:\d+:\d+/);
  });

  it("skips what it cannot read when lenient", () => {
    const map = read(
      `export default function () {
        list.forEach((x) => this.route(x));
        this.route("about");
      }`,
      { lenient: true }
    );

    expect(map.routes.map((route) => route.name)).toEqual(["about"]);
  });
});

describe("deriving", () => {
  it("nests names and paths, and resets only the name", () => {
    const { urls, bundleByRoute } = tablesFor([
      {
        core: true,
        source: `export default function () {
        this.route("admin", function () {
          this.route("adminPlugins", { path: "/plugins", resetNamespace: true }, function () {
            this.route("show", { path: "/:plugin_id" });
          });
        });
      }`,
      },
      `export default {
        resource: "admin.adminPlugins.show",
        map() {
          this.route("discourse-chat-incoming-webhooks", { path: "hooks", bundleName: "webhooks" }, function () {
            this.route("edit", { path: "/:id/edit" });
          });
        },
      };`,
    ]);

    expect(bundleByRoute).toEqual({
      "admin-plugins.show.discourse-chat-incoming-webhooks": "webhooks",
      "admin-plugins.show.discourse-chat-incoming-webhooks.edit": "webhooks",
    });
    expect(urls).toEqual([
      { bundleName: "webhooks", url: "admin/plugins/*/hooks/*" },
    ]);
  });

  it("gives a plugin route with no bundleName the default bundle", () => {
    const { bundleByRoute, urls } = tablesFor([
      {
        core: true,
        source: `export default function () { this.route("user"); }`,
      },
      `export default function () {
        this.route("standalone");
        this.route("named", { bundleName: "named" });
      }`,
    ]);

    expect(bundleByRoute).toEqual({ standalone: "default", named: "named" });
    expect(bundleByRoute.user).toBeUndefined();
    expect(urls).toContainEqual({ bundleName: "default", url: "standalone/*" });
  });

  it("groups siblings into one bundle", () => {
    const { bundleByRoute, urls } = tablesFor([
      `export default function () {
        this.route("chat", { bundleName: "chat" }, function () {
          this.route("disabled", { bundleName: "foo" });
          this.route("search", { bundleName: "foo" });
        });
      }`,
    ]);

    expect(bundleByRoute).toEqual({
      chat: "chat",
      "chat.disabled": "foo",
      "chat.search": "foo",
    });
    expect(urls).toEqual([
      { bundleName: "foo", url: "chat/disabled/*" },
      { bundleName: "foo", url: "chat/search/*" },
      { bundleName: "chat", url: "chat/*" },
    ]);
  });

  it("keeps a splat distinct from a dynamic segment", () => {
    // A `:dynamic` is one segment, a `*splat` is the rest of the route path.
    const { urls } = tablesFor([
      {
        core: true,
        source: `export default function () {
          this.route("discovery", { path: "/" }, function () {
            this.route("category", { path: "/c/*category_slug_path_with_id" });
          });
        }`,
      },
      `export default {
        resource: "discovery.category",
        map() {
          this.route("extras", { path: "/:id/extras", bundleName: "extras" });
        },
      };`,
    ]);

    expect(urls).toEqual([{ bundleName: "extras", url: "c/**/*/extras/*" }]);
  });

  it("orders urls most specific first", () => {
    const { urls } = tablesFor([
      `export default function () {
        this.route("chat", { bundleName: "chat" }, function () {
          this.route("search", { bundleName: "foo" });
        });
      }`,
    ]);

    expect(urls.map((entry) => entry.url)).toEqual(["chat/search/*", "chat/*"]);
  });

  it("takes a bundle name from the map itself", () => {
    const { bundleByRoute } = tablesFor([
      `export default {
         resource: "admin",
         bundleName: "workflows",
         map() {
           this.route("workflows", function () { this.route("show"); });
           this.route("variables");
         },
       };`,
      `export default function () { this.route("admin"); }`,
    ]);

    expect(bundleByRoute["admin.workflows"]).toBe("workflows");
    expect(bundleByRoute["admin.workflows.show"]).toBe("workflows");
    expect(bundleByRoute["admin.variables"]).toBe("workflows");
  });

  it("lets a route override the bundle the map names", () => {
    const { bundleByRoute } = tablesFor([
      `export default {
         resource: "admin",
         bundleName: "workflows",
         map() {
           this.route("a");
           this.route("b", { bundleName: "other" }, function () {
             this.route("c");
           });
         },
       };`,
      `export default function () { this.route("admin"); }`,
    ]);

    expect(bundleByRoute["admin.a"]).toBe("workflows");
    expect(bundleByRoute["admin.b"]).toBe("other");
    expect(bundleByRoute["admin.b.c"]).toBe("other");
  });

  it("rejects a computed bundle name on the map", () => {
    expect(() =>
      tablesFor([
        `export default {
           resource: "admin",
           bundleName: SOME_CONSTANT,
           map() { this.route("a"); },
         };`,
      ])
    ).toThrow(/`bundleName` must be a string literal/);
  });

  it("orders a dynamic child ahead of the parent it sits under", () => {
    const { urls } = tablesFor([
      `export default function () {
        this.route("workflows", { bundleName: "workflows" }, function () {
          this.route("show", { path: "/:id", bundleName: "editor" });
        });
      }`,
    ]);

    expect(urls.map((entry) => entry.url)).toEqual([
      "workflows/*/*",
      "workflows/*",
    ]);
  });

  it("merges maps that extend the same route", () => {
    const { bundleByRoute } = tablesFor([
      `export default function () { this.route("chat", { bundleName: "chat" }); }`,
      `export default function () {
        this.route("chat", function () { this.route("extra"); });
      }`,
    ]);

    expect(bundleByRoute["chat.extra"]).toBe("chat");
  });

  it("reports a resource that mounts on nothing", () => {
    const { unmounted } = buildRouteTree([
      read(
        `export default { resource: "discovery.filter", map() { this.route("x"); } };`
      ),
    ]);

    expect(unmounted).toHaveLength(1);
  });
});
