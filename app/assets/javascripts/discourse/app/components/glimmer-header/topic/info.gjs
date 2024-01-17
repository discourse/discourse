import icon from "discourse-common/helpers/d-icon";
import renderTags from "discourse/lib/render-tags";
import { topicFeaturedLinkNode } from "discourse/lib/render-topic-featured-link";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { action } from "@ember/object";
import i18n from "discourse-common/helpers/i18n";
import Component from "@glimmer/component";
import SidebarToggle from "../sidebar-toggle";
import PluginOutlet from "../../plugin-outlet";
import and from "truth-helpers/helpers/and";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DiscourseURL from "discourse/lib/url";

import Status from "./status";

let _additionalFancyTitleClasses = [];

export function addHeaderFancyTitleClass(className) {
  _additionalFancyTitleClasses.push(className);
}

export default class Info extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked twoRows = false;

  get showPM() {
    return !this.args.topic.is_warning && this.args.topic.isPrivateMessage;
  }

  <template>
    <div class="extra-info-wrapper">
      <div class={{concatClass (if this.twoRows "two-rows") "extra-info"}}>
        {{#if this.showPM}}
          <a
            class="private-message-glyph-wrapper"
            href={{this.currentUser.pmPath topic}}
            aria-label={{i18n "user.messages.inbox"}}
          >
            {{icon "envelope" class="private-message-glyph"}}
          </a>
        {{/if}}

        {{#if (and @topic.fancyTitle @topic.url)}}
          <Status @topic={{@topic}} @disableActions={{@disableActions}} />

          <a
            class={{concatClass "topic-link" this.additionalFancyTitleClasses}}
            {{on "click" this.jumpToTopPost}}
            href={{@topic.url}}
            data-topic-id={{@topic.id}}
          >
            <span>{{@topic.fancyTitle}}</span>
          </a>

          <span class="header-topic-title-suffix">
            <PluginOutlet
              @name="header-topic-title-suffix"
              @outletArgs={{hash topic=@topic}}
            />
          </span>
        {{/if}}
      </div>
    </div>
  </template>

  constructor() {
    super(...arguments);
    const heading = [];

    // const loaded = topic.get("details.loaded");
    // const fancyTitle = topic.get("fancyTitle");
    // const href = topic.get("url");

    // if (fancyTitle && href) {
    //   heading.push(this.attach("topic-status", attrs));

    //   const titleHTML = new RawHtml({ html: `<span>${fancyTitle}</span>` });
    //   heading.push(
    //     this.attach("link", {
    //       className: this.buildFancyTitleClass(),
    //       action: "jumpToTopPost",
    //       href,
    //       attributes: { "data-topic-id": topic.get("id") },
    //       contents: () => titleHTML,
    //     })
    //   );

    //   heading.push(
    //     new RenderGlimmer(
    //       this,
    //       "span.header-topic-title-suffix",
    //       hbs`<PluginOutlet @name="header-topic-title-suffix" @outletArgs={{@data.outletArgs}}/>`,
    //       {
    //         outletArgs: {
    //           topic,
    //         },
    //       }
    //     )
    //   );
    // }

    // this.headerElements = [h("h1.header-title", heading)];
    // const category = topic.get("category");

    // if (loaded || category) {
    //   if (
    //     category &&
    //     (!category.isUncategorizedCategory ||
    //       !this.siteSettings.suppress_uncategorized_badge)
    //   ) {
    //     const parentCategory = category.get("parentCategory");
    //     const categories = [];
    //     if (parentCategory) {
    //       if (
    //         this.siteSettings.max_category_nesting > 2 &&
    //         !this.site.mobileView
    //       ) {
    //         const grandParentCategory = parentCategory.get("parentCategory");
    //         if (grandParentCategory) {
    //           categories.push(
    //             this.attach("category-link", { category: grandParentCategory })
    //           );
    //         }
    //       }

    //       categories.push(
    //         this.attach("category-link", { category: parentCategory })
    //       );
    //     }
    //     categories.push(
    //       this.attach("category-link", { category, hideParent: true })
    //     );

    //     this.headerElements.push(h("div.categories-wrapper", categories));
    //     this.twoRows = true;
    //   }

    //   let extra = [];
    //   const tags = renderTags(topic);
    //   if (tags && tags.length > 0) {
    //     extra.push(new RawHtml({ html: tags }));
    //   }

    //   if (showPM) {
    //     const maxHeaderParticipants = extra.length > 0 ? 5 : 10;
    //     const participants = [];
    //     const topicDetails = topic.get("details");
    //     const totalParticipants =
    //       topicDetails.allowed_users.length +
    //       topicDetails.allowed_groups.length;

    //     topicDetails.allowed_users.some((user) => {
    //       if (participants.length >= maxHeaderParticipants) {
    //         return true;
    //       }

    //       participants.push(
    //         this.attach("topic-header-participant", {
    //           type: "user",
    //           user,
    //           username: user.username,
    //         })
    //       );
    //     });

    //     topicDetails.allowed_groups.some((group) => {
    //       if (participants.length >= maxHeaderParticipants) {
    //         return true;
    //       }

    //       participants.push(
    //         this.attach("topic-header-participant", {
    //           type: "group",
    //           group,
    //           username: group.name,
    //         })
    //       );
    //     });

    //     if (totalParticipants > maxHeaderParticipants) {
    //       const remaining = totalParticipants - maxHeaderParticipants;
    //       participants.push(
    //         this.attach("link", {
    //           className: "more-participants",
    //           action: "jumpToTopPost",
    //           href,
    //           attributes: { "data-topic-id": topic.get("id") },
    //           contents: () => `+${remaining}`,
    //         })
    //       );
    //     }

    //     extra.push(h("div.topic-header-participants", participants));
    //   }

    //   extra = extra.concat(applyDecorators(this, "after-tags", attrs, state));

    //   if (this.siteSettings.topic_featured_link_enabled) {
    //     const featured = topicFeaturedLinkNode(attrs.topic);
    //     if (featured) {
    //       extra.push(featured);
    //     }
    //   }
    //   if (extra.length) {
    //     this.headerElements.push(h("div.topic-header-extra", extra));
    //     this.twoRows = true;
    //   }
    // }
    // this.contents = h("div.title-wrapper", this.headerElements);
  }

  @action
  jumpToTopPost(e) {
    e.preventDefault();
    if (this.args.topic) {
      DiscourseURL.routeTo(this.args.topic.firstPostUrl, {
        keepFilter: true,
      });
    }
  }

  get additionalFancyTitleClasses() {
    return _additionalFancyTitleClasses.join(" ");
  }
}

// createWidget("topic-header-participant", {
//   tagName: "span",

//   buildClasses(attrs) {
//     return `trigger-${attrs.type}-card`;
//   },

//   html(attrs) {
//     const { user, group } = attrs;
//     let content, url;

//     if (attrs.type === "user") {
//       content = avatarImg("tiny", {
//         template: user.avatar_template,
//         username: user.username,
//       });
//       url = user.get("path");
//     } else {
//       content = [iconNode("users")];
//       url = getURL(`/g/${group.name}`);
//       content.push(h("span", group.name));
//     }

//     return h(
//       "a.icon",
//       {
//         attributes: {
//           href: url,
//           "data-auto-route": true,
//           title: attrs.username,
//         },
//       },
//       content
//     );
//   },

//   click(e) {
//     this.appEvents.trigger(
//       `topic-header:trigger-${this.attrs.type}-card`,
//       this.attrs.username,
//       e.target
//     );
//     e.preventDefault();
//   },
// });
