import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { resetTagSourceCache } from "discourse/lib/tag-source";
import Site from "discourse/models/site";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  MULTI_RECIPE_ARGS,
  RECIPE_ARGS,
} from "discourse/ui-kit/select/recipes/-internals/recipe-args";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import DSelectCategoryFilter from "discourse/ui-kit/select/recipes/categories/d-select-category-filter";
import DSelectGroup from "discourse/ui-kit/select/recipes/groups/d-select-group";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import DSelectTagFilter from "discourse/ui-kit/select/recipes/tags/d-select-tag-filter";
import DSelectTagGroup from "discourse/ui-kit/select/recipes/tags/d-select-tag-group";
import DSelectTopic from "discourse/ui-kit/select/recipes/topics/d-select-topic";
import DSelectTopicList from "discourse/ui-kit/select/recipes/topics/d-select-topic-list";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";

const IDENTIFIER = "recipe-args";
const LEGACY_KIND = "recipe-args-kind";
const INSTANCE_CONTEXT = Object.freeze({ caller: "recipe-args" });

/**
 * Each recipe holding two values, the first locked (by name where the recipe holds objects).
 * Values are left unresolved where the recipe would fetch them, since a locked chip doesn't
 * depend on its label.
 */
const RECIPES = [
  {
    name: "DSelectGroup",
    component: DSelectGroup,
    emit: "names",
    value: () => ["staff", "support"],
  },
  { name: "DSelectUser", component: DSelectUser, value: () => ["sam", "eve"] },
  {
    name: "DSelectTag",
    component: DSelectTag,
    // Known ids and a differently cased name: the lock must reach the id the tag is held by.
    value: () => [
      { id: 5, name: "JavaScript" },
      { id: 6, name: "ruby" },
    ],
    locked: () => ["javascript"],
    key: (tag) => tag.name,
    lockedKey: "JavaScript",
  },
  {
    name: "DSelectTagGroup",
    component: DSelectTagGroup,
    value: () => ["Languages", "Frameworks"],
  },
  {
    name: "DSelectTagFilter",
    component: DSelectTagFilter,
    value: () => [
      { id: 1, name: "JavaScript" },
      { id: 2, name: "ruby" },
    ],
    locked: () => ["JavaScript"],
    key: (tag) => tag.name,
    lockedKey: "JavaScript",
  },
  {
    name: "DSelectCategory",
    component: DSelectCategory,
    emit: "ids",
    value: () =>
      Site.current()
        .categories.slice(0, 2)
        .map(({ id }) => id),
  },
  { name: "DSelectTopic", component: DSelectTopic, value: () => [11, 12] },
  {
    name: "DSelectTopicList",
    component: DSelectTopicList,
    value: () => [11, 12],
  },
  {
    name: "DSelectCategoryFilter",
    component: DSelectCategoryFilter,
    single: true,
  },
];

/** A chip's remove button, locked or not. */
function removeButton(locked) {
  return document.querySelector(
    `.d-select__chip${locked ? ".--locked" : ":not(.--locked)"} .d-select__chip-remove`
  );
}

/** Records the instance context of every config step for the shared identifier. */
function watchIdentifier() {
  const seen = [];
  withPluginApi((api) =>
    api.registerValueTransformer("select-customizations", ({ value }) =>
      value.forIdentifier(IDENTIFIER, (spec) =>
        spec.config((_current, context) => {
          seen.push(context.instanceContext);
        })
      )
    )
  );
  return seen;
}

/** How each shared argument shows that a recipe passed it on. */
const PROBES = {
  identifier(assert, { seen }) {
    assert.true(seen.length > 0, "a customization for its identifier runs");
  },
  instanceContext(assert, { seen }) {
    assert.true(
      seen.length > 0 && seen.every((context) => context === INSTANCE_CONTEXT),
      "customizations receive its instance context"
    );
  },
  legacyKind(assert) {
    assert.dom(".d-select").hasClass(LEGACY_KIND, "the root carries its kind");
  },
  lockedValues(assert) {
    assert
      .dom(".d-select__chip.--locked")
      .exists({ count: 1 }, "the locked held value can't be removed");
  },
};

module(
  "Integration | ui-kit | select | recipes | shared arguments",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      resetTagSourceCache();
      this.owner.lookup("service:site").groups = [
        { id: 3, name: "staff", automatic: true },
        { id: 41, name: "support" },
      ];
      pretender.get("/u/search/users", () => response({ users: [] }));
      pretender.get("/tags/filter/search", () => response({ results: [] }));
      pretender.get("/tag_groups/filter/search", () =>
        response({ results: [] })
      );
      pretender.get("/search/query", () => response({ topics: [] }));
      pretender.get("/topics/lookup.json", () => response({ topics: [] }));
    });

    test("every shared argument has a probe", function (assert) {
      assert.deepEqual(
        Object.keys(PROBES).sort(),
        [...MULTI_RECIPE_ARGS].sort(),
        "a newly shared argument needs a probe here"
      );
    });

    for (const recipe of RECIPES.filter(({ single }) => !single)) {
      test(`${recipe.name} keeps a locked value through a change`, async function (assert) {
        const value = recipe.value();
        const lockedValues = recipe.locked?.() ?? value.slice(0, 1);
        const lockedKey = recipe.lockedKey ?? String(lockedValues[0]);
        const key = recipe.key ?? String;
        const emitted = [];
        const onChange = (next) => emitted.push(next);
        const Recipe = recipe.component;

        await render(
          <template>
            <Recipe
              @emit={{recipe.emit}}
              @lockedValues={{lockedValues}}
              @multiple={{true}}
              @onChange={{onChange}}
              @value={{value}}
            />
          </template>
        );

        await click(removeButton(true));
        assert.deepEqual(emitted, [], "the locked chip removes nothing");

        await click(removeButton(false));
        const keys = emitted.at(-1)?.map(key) ?? [];
        assert.deepEqual(
          keys.map(String),
          [lockedKey],
          "the change still holds the locked value, and only it"
        );
      });
    }

    for (const recipe of RECIPES) {
      test(`${recipe.name} forwards the shared arguments`, async function (assert) {
        const seen = watchIdentifier();
        const value = recipe.single ? undefined : recipe.value();
        const lockedValues = recipe.locked?.() ?? value?.slice(0, 1);
        const Recipe = recipe.component;

        await render(
          <template>
            <Recipe
              @emit={{recipe.emit}}
              @identifier={{IDENTIFIER}}
              @instanceContext={{INSTANCE_CONTEXT}}
              @legacyKind={{LEGACY_KIND}}
              @lockedValues={{lockedValues}}
              @multiple={{if recipe.single false true}}
              @value={{value}}
            />
          </template>
        );

        const keys = recipe.single ? RECIPE_ARGS : MULTI_RECIPE_ARGS;
        for (const key of keys) {
          PROBES[key](assert, { seen });
        }
      });
    }
  }
);
