import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import { categories } from "../../../lib/select-fixtures.js";
import BadgesSelectExample from "../../examples/molecules/select/showcases/badges.gjs";
import badgesSource from "../../examples/molecules/select/showcases/badges?source=file";
import CategoriesSelectExample from "../../examples/molecules/select/showcases/categories.gjs";
import categoriesSource from "../../examples/molecules/select/showcases/categories?source=file";
import ColorsSelectExample from "../../examples/molecules/select/showcases/colors.gjs";
import colorsSource from "../../examples/molecules/select/showcases/colors?source=file";
import EmojiSelectExample from "../../examples/molecules/select/showcases/emoji.gjs";
import emojiSource from "../../examples/molecules/select/showcases/emoji?source=file";
import GroupsSelectExample from "../../examples/molecules/select/showcases/groups.gjs";
import groupsSource from "../../examples/molecules/select/showcases/groups?source=file";
import NotificationsSelectExample from "../../examples/molecules/select/showcases/notifications.gjs";
import notificationsSource from "../../examples/molecules/select/showcases/notifications?source=file";
import ReviewersSelectExample from "../../examples/molecules/select/showcases/reviewers.gjs";
import reviewersSource from "../../examples/molecules/select/showcases/reviewers?source=file";
import TagsSelectExample from "../../examples/molecules/select/showcases/tags.gjs";
import tagsSource from "../../examples/molecules/select/showcases/tags?source=file";
import StyleguideExample from "../../styleguide-example.gjs";

export default class SelectShowcases extends Component {
  @service store;

  @cached
  get categories() {
    return categories(this.store);
  }

  @action
  specialCategories() {
    return [
      this.store.createRecord("category", {
        id: 0,
        name: i18n(
          "styleguide.sections.select.showcases.categories.uncategorized"
        ),
        slug: "uncategorized",
        color: "0088CC",
        description_excerpt: i18n(
          "styleguide.sections.select.showcases.categories.uncategorized_description"
        ),
        topic_count: 19,
      }),
    ];
  }

  <template>
    <StyleguideExample
      @code={{reviewersSource}}
      @description={{i18n
        "styleguide.sections.select.showcases.reviewers.description"
      }}
      @title={{i18n "styleguide.sections.select.showcases.reviewers.title"}}
      @tryThis={{i18n
        "styleguide.sections.select.showcases.reviewers.try_this"
      }}
    >
      <div
        class="select-showcases__control"
        data-test-select-showcase="reviewers"
      >
        <ReviewersSelectExample />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @code={{categoriesSource}}
      @description={{i18n
        "styleguide.sections.select.showcases.categories.description"
      }}
      @title={{i18n "styleguide.sections.select.showcases.categories.title"}}
      @tryThis={{i18n
        "styleguide.sections.select.showcases.categories.try_this"
      }}
    >
      <div
        class="select-showcases__control"
        data-test-select-showcase="categories"
      >
        <CategoriesSelectExample
          @items={{this.categories}}
          @specialItems={{this.specialCategories}}
        />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @code={{tagsSource}}
      @description={{i18n
        "styleguide.sections.select.showcases.tags.description"
      }}
      @title={{i18n "styleguide.sections.select.showcases.tags.title"}}
      @tryThis={{i18n "styleguide.sections.select.showcases.tags.try_this"}}
    >
      <div class="select-showcases__control" data-test-select-showcase="tags">
        <TagsSelectExample />
      </div>
    </StyleguideExample>

    <StyleguideExample
      data-test-select-showcase="notifications"
      @code={{notificationsSource}}
      @description={{i18n
        "styleguide.sections.select.showcases.notifications.description"
      }}
      @title={{i18n "styleguide.sections.select.showcases.notifications.title"}}
      @tryThis={{i18n
        "styleguide.sections.select.showcases.notifications.try_this"
      }}
    >
      <div class="select-showcases__control">
        <NotificationsSelectExample />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @code={{colorsSource}}
      @description={{i18n
        "styleguide.sections.select.showcases.colors.description"
      }}
      @title={{i18n "styleguide.sections.select.showcases.colors.title"}}
      @tryThis={{i18n "styleguide.sections.select.showcases.colors.try_this"}}
    >
      <div class="select-showcases__control">
        <ColorsSelectExample />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @code={{emojiSource}}
      @description={{i18n
        "styleguide.sections.select.showcases.emoji.description"
      }}
      @title={{i18n "styleguide.sections.select.showcases.emoji.title"}}
      @tryThis={{i18n "styleguide.sections.select.showcases.emoji.try_this"}}
    >
      <div class="select-showcases__control">
        <EmojiSelectExample />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @code={{groupsSource}}
      @description={{i18n
        "styleguide.sections.select.showcases.groups.description"
      }}
      @title={{i18n "styleguide.sections.select.showcases.groups.title"}}
      @tryThis={{i18n "styleguide.sections.select.showcases.groups.try_this"}}
    >
      <div class="select-showcases__control">
        <GroupsSelectExample />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @code={{badgesSource}}
      @description={{i18n
        "styleguide.sections.select.showcases.badges.description"
      }}
      @title={{i18n "styleguide.sections.select.showcases.badges.title"}}
      @tryThis={{i18n "styleguide.sections.select.showcases.badges.try_this"}}
    >
      <div class="select-showcases__control">
        <BadgesSelectExample />
      </div>
    </StyleguideExample>
  </template>
}
