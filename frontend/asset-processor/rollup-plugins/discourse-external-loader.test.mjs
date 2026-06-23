import { expect, test } from "vitest";
import discourseExternalLoader from "./discourse-external-loader.js";

const plugin = discourseExternalLoader({ basePath: "discourse/plugins/myplugin/" });
const resolve = (source, attributes = {}) =>
  plugin.resolveId(source, "importer.js", { attributes });

test("cross-plugin imports are optional by default (gets an `?optional` marker)", async () => {
  expect(await resolve("discourse/plugins/chat/models/chat-channel")).toEqual({
    id: "discourse/plugins/chat/models/chat-channel?optional",
    external: true,
  });
});

test('explicit `discoursePlugin: "optional"` is marked the same as the default', async () => {
  expect(
    await resolve("discourse/plugins/chat/models/chat-channel", {
      discoursePlugin: "optional",
    })
  ).toEqual({
    id: "discourse/plugins/chat/models/chat-channel?optional",
    external: true,
  });
});

test('`discoursePlugin: "required"` opts into a hard dependency (no marker)', async () => {
  expect(
    await resolve("discourse/plugins/chat/models/chat-channel", {
      discoursePlugin: "required",
    })
  ).toEqual({
    id: "discourse/plugins/chat/models/chat-channel",
    external: true,
  });
});

test("rejects an unknown `discoursePlugin` value", async () => {
  await expect(
    resolve("discourse/plugins/chat/models/chat-channel", {
      discoursePlugin: "maybe",
    })
  ).rejects.toThrow(/Invalid `discoursePlugin` import attribute "maybe"/);
});

test("non-plugin externals are left untouched", async () => {
  expect(await resolve("@ember/component")).toEqual({
    id: "@ember/component",
    external: true,
  });
});
