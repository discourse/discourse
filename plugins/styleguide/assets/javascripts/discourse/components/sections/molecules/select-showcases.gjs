import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import { categories } from "../../../lib/select-fixtures";
import BadgesSelectExample from "../../examples/molecules/select/pickers/badges";
import badgesSource from "../../examples/molecules/select/pickers/badges?source=file";
import CategoriesSelectExample from "../../examples/molecules/select/pickers/categories";
import categoriesSource from "../../examples/molecules/select/pickers/categories?source=file";
import ColorsSelectExample from "../../examples/molecules/select/pickers/colors";
import colorsSource from "../../examples/molecules/select/pickers/colors?source=file";
import EmojiSelectExample from "../../examples/molecules/select/pickers/emoji";
import emojiSource from "../../examples/molecules/select/pickers/emoji?source=file";
import GroupsSelectExample from "../../examples/molecules/select/pickers/groups";
import groupsSource from "../../examples/molecules/select/pickers/groups?source=file";
import NotificationsSelectExample from "../../examples/molecules/select/pickers/notifications";
import notificationsSource from "../../examples/molecules/select/pickers/notifications?source=file";
import ReviewersSelectExample from "../../examples/molecules/select/pickers/reviewers";
import reviewersSource from "../../examples/molecules/select/pickers/reviewers?source=file";
import TagsSelectExample from "../../examples/molecules/select/pickers/tags";
import tagsSource from "../../examples/molecules/select/pickers/tags?source=file";
import StyleguideExample from "../../styleguide-example";

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
          "styleguide.sections.select.pickers.categories.uncategorized"
        ),
        slug: "uncategorized",
        color: "0088CC",
        description_excerpt: i18n(
          "styleguide.sections.select.pickers.categories.uncategorized_description"
        ),
        topic_count: 19,
      }),
    ];
  }

  <template>
    <StyleguideExample
      @code={{reviewersSource}}
      @description={{i18n
        "styleguide.sections.select.pickers.reviewers.description"
      }}
      @title={{i18n "styleguide.sections.select.pickers.reviewers.title"}}
      @tryThis={{i18n "styleguide.sections.select.pickers.reviewers.try_this"}}
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
        "styleguide.sections.select.pickers.categories.description"
      }}
      @title={{i18n "styleguide.sections.select.pickers.categories.title"}}
      @tryThis={{i18n "styleguide.sections.select.pickers.categories.try_this"}}
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
        "styleguide.sections.select.pickers.tags.description"
      }}
      @title={{i18n "styleguide.sections.select.pickers.tags.title"}}
      @tryThis={{i18n "styleguide.sections.select.pickers.tags.try_this"}}
    >
      <div class="select-showcases__control" data-test-select-showcase="tags">
        <TagsSelectExample />
      </div>
    </StyleguideExample>

    <StyleguideExample
      data-test-select-showcase="notifications"
      @code={{notificationsSource}}
      @description={{i18n
        "styleguide.sections.select.pickers.notifications.description"
      }}
      @title={{i18n "styleguide.sections.select.pickers.notifications.title"}}
      @tryThis={{i18n
        "styleguide.sections.select.pickers.notifications.try_this"
      }}
    >
      <div class="select-showcases__control">
        <NotificationsSelectExample />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @code={{colorsSource}}
      @description={{i18n
        "styleguide.sections.select.pickers.colors.description"
      }}
      @title={{i18n "styleguide.sections.select.pickers.colors.title"}}
      @tryThis={{i18n "styleguide.sections.select.pickers.colors.try_this"}}
    >
      <div class="select-showcases__control">
        <ColorsSelectExample />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @code={{emojiSource}}
      @description={{i18n
        "styleguide.sections.select.pickers.emoji.description"
      }}
      @title={{i18n "styleguide.sections.select.pickers.emoji.title"}}
      @tryThis={{i18n "styleguide.sections.select.pickers.emoji.try_this"}}
    >
      <div class="select-showcases__control">
        <EmojiSelectExample />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @code={{groupsSource}}
      @description={{i18n
        "styleguide.sections.select.pickers.groups.description"
      }}
      @title={{i18n "styleguide.sections.select.pickers.groups.title"}}
      @tryThis={{i18n "styleguide.sections.select.pickers.groups.try_this"}}
    >
      <div class="select-showcases__control">
        <GroupsSelectExample />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @code={{badgesSource}}
      @description={{i18n
        "styleguide.sections.select.pickers.badges.description"
      }}
      @title={{i18n "styleguide.sections.select.pickers.badges.title"}}
      @tryThis={{i18n "styleguide.sections.select.pickers.badges.try_this"}}
    >
      <div class="select-showcases__control">
        <BadgesSelectExample />
      </div>
    </StyleguideExample>
  </template>
}
