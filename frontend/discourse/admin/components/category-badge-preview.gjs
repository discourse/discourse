import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { AUTO_GROUPS } from "discourse/lib/constants";

export default class CategoryBadgePreview extends Component {
  get showBadge() {
    if (this.args.category.id) {
      return false;
    }

    const name =
      this.args.previewData?.previewName || this.args.category.name || "";
    return name.trim().length > 0;
  }

  @cached
  get badgeHtml() {
    if (!this.showBadge) {
      return null;
    }

    const category = this.args.category;
    const permissions = category.permissions;
    let isRestricted = false;

    if (!permissions || permissions.length === 0) {
      isRestricted = true;
    } else {
      const onlyEveryone =
        permissions.length === 1 &&
        (permissions[0].group_id === AUTO_GROUPS.everyone.id ||
          permissions[0].group_name === "everyone");
      isRestricted = !onlyEveryone;
    }

    const parentId =
      this.args.previewData?.previewParentCategoryId ??
      category.parent_category_id;

    const previewCategory = {
      name: this.args.previewData?.previewName || category.name,
      color: this.args.previewData?.previewColor || category.color,
      text_color:
        this.args.previewData?.previewTextColor || category.text_color,
      style_type:
        this.args.previewData?.previewStyleType ||
        category.style_type ||
        "icon",
      emoji: this.args.previewData?.previewEmoji || category.emoji,
      icon: this.args.previewData?.previewIcon || category.icon,
      read_restricted: isRestricted,
      parent_category_id: parentId,
    };

    return categoryBadgeHTML(previewCategory, {
      link: false,
      previewColor: true,
    });
  }

  <template>
    {{#if this.showBadge}}
      {{htmlSafe this.badgeHtml}}
    {{/if}}
  </template>
}
