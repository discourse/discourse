import { module, test } from "qunit";
import {
  hasEventsSubcategories,
  offersCategoryChoice,
} from "discourse/plugins/discourse-events/discourse/lib/events-categories";

const site = {
  categories: [
    { id: 1 },
    { id: 2, parent_category_id: 1 },
    { id: 3, parent_category_id: 2 },
    { id: 4 },
  ],
};

const settings = (ids) => ({ events_calendar_categories: ids.join("|") });

module("Unit | Lib | events-categories", function () {
  test("offersCategoryChoice: hidden for exactly one events category", function (assert) {
    assert.false(offersCategoryChoice(settings([1])));
    assert.true(offersCategoryChoice(settings([1, 4])));
    assert.true(offersCategoryChoice(settings([])));
  });

  test("hasEventsSubcategories: needs a chosen or sole events category", function (assert) {
    assert.false(
      hasEventsSubcategories({
        args: {},
        siteSettings: settings([1, 4]),
        site,
      })
    );
  });

  test("hasEventsSubcategories: with one events category nothing else can hold events", function (assert) {
    assert.false(
      hasEventsSubcategories({ args: {}, siteSettings: settings([1]), site })
    );
  });

  test("hasEventsSubcategories: only counts subcategories that are events categories", function (assert) {
    assert.false(
      hasEventsSubcategories({
        args: { categoryId: 1 },
        siteSettings: settings([1, 4]),
        site,
      }),
      "subcategories exist but none holds events"
    );
    assert.true(
      hasEventsSubcategories({
        args: { categoryId: 1 },
        siteSettings: settings([1, 3]),
        site,
      }),
      "a nested subcategory that holds events counts"
    );
    assert.false(
      hasEventsSubcategories({
        args: { categoryId: 4 },
        siteSettings: settings([1, 4]),
        site,
      }),
      "a category without subcategories"
    );
  });

  test("hasEventsSubcategories: with no events categories configured, any subcategory counts", function (assert) {
    assert.true(
      hasEventsSubcategories({
        args: { categoryId: 1 },
        siteSettings: settings([]),
        site,
      })
    );
    assert.false(
      hasEventsSubcategories({
        args: { categoryId: 4 },
        siteSettings: settings([]),
        site,
      })
    );
  });
});
