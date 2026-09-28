import { module, test } from "qunit";
import { arrangeTabs } from "discourse/lib/mobile-tab-bar";

const tabs = (...keys) => keys.map((key) => ({ key }));
const keysOf = (arranged) =>
  arranged.map((tab) =>
    tab.overflow ? `more(${tab.overflow.map((t) => t.key).join(",")})` : tab.key
  );
const options = {
  foldOrder: ["admin"],
  keep: ["search"],
  moreTab: { key: "more" },
};

module("Unit | Lib | mobile-tab-bar", function () {
  test("arrangeTabs keeps every tab when they fit", function (assert) {
    assert.deepEqual(
      keysOf(
        arrangeTabs(tabs("main", "chat", "ai", "search", "admin"), options)
      ),
      ["main", "chat", "ai", "search", "admin"]
    );
  });

  test("arrangeTabs folds tabs in fold order first, then from the end, and puts More last", function (assert) {
    assert.deepEqual(
      keysOf(
        arrangeTabs(
          tabs("main", "chat", "ai", "docs", "search", "admin"),
          options
        )
      ),
      ["main", "chat", "ai", "search", "more(docs,admin)"]
    );

    assert.deepEqual(
      keysOf(
        arrangeTabs(
          tabs("main", "chat", "ai", "docs", "wiki", "search", "admin"),
          options
        )
      ),
      ["main", "chat", "ai", "search", "more(docs,wiki,admin)"],
      "held tabs keep their display order"
    );
  });

  test("arrangeTabs never folds the first tab or tabs it is told to keep", function (assert) {
    assert.deepEqual(
      keysOf(
        arrangeTabs(tabs("main", "a", "search", "b"), { ...options, max: 2 })
      ),
      ["main", "search", "more(a,b)"]
    );
  });
});
