import fs from "node:fs";
import { describe, expect, it } from "vitest";
import {
  buildRouteTree,
  deriveRoutes,
  parseRouteMap,
  routeTablesFor,
} from "./route-map-parser";

// `@rollup/browser` fetches its wasm parser, which node cannot do for a file url. The asset
// processor bundle inlines it instead, so this shim is only needed here.
const realFetch = globalThis.fetch;
globalThis.fetch = async (url) => {
  const target = url instanceof URL ? url : new URL(url);
  if (target.protocol === "file:") {
    return new Response(fs.readFileSync(target));
  }
  return realFetch(url);
};

const { rollup } = await import("@rollup/browser");

let parse;
await rollup({
  input: "entry",
  plugins: [
    {
      name: "capture-parse",
      resolveId: (id) => id,
      load: () => "export default 1",
      buildStart() {
        parse = (code) => this.parse(code);
      },
    },
  ],
});

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
  return routeTablesFor(deriveRoutes(buildRouteTree(maps).root));
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
