import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import { findActiveLink } from "discourse/lib/sidebar/active-link";
import TagSectionLink from "discourse/lib/sidebar/user/tags-section/tag-section-link";
import { and, eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import AllTagsSectionLink from "../common/all-tags-section-link";
import Section from "../section";
import SectionLink from "../section-link";

export default class SidebarAnonymousTagsSection extends Component {
  @service router;
  @service topicTrackingState;
  @service site;

  @cached
  get activeLink() {
    return findActiveLink(this.sectionLinks, this.router);
  }

  get displaySection() {
    return (
      this.site.anonymous_default_navigation_menu_tags?.length > 0 ||
      this.site.navigation_menu_site_top_tags?.length > 0
    );
  }

  @cached
  get sectionLinks() {
    return (
      this.site.anonymous_default_navigation_menu_tags ||
      this.site.navigation_menu_site_top_tags
    ).map((tag) => {
      return new TagSectionLink({
        tag,
        topicTrackingState: this.topicTrackingState,
      });
    });
  }

  <template>
    {{#if this.displaySection}}
      <Section
        @activeLink={{this.activeLink}}
        @collapsable={{@collapsable}}
        @expandWhenActive={{@expandActiveSection}}
        @headerLinkText={{i18n "sidebar.sections.tags.header_link_text"}}
        @sectionName="tags"
      >

        {{#each this.sectionLinks as |sectionLink|}}
          <SectionLink
            data-tag-name={{sectionLink.tagName}}
            @content={{sectionLink.text}}
            @currentWhen={{sectionLink.currentWhen}}
            @models={{sectionLink.models}}
            @prefixColor={{sectionLink.prefixColor}}
            @prefixType={{sectionLink.prefixType}}
            @prefixValue={{sectionLink.prefixValue}}
            @route={{sectionLink.route}}
            @scrollIntoView={{and
              @scrollActiveLinkIntoView
              (eq sectionLink.name this.activeLink.name)
            }}
            @title={{sectionLink.title}}
          />
        {{/each}}

        <AllTagsSectionLink
          @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
        />
      </Section>
    {{/if}}
  </template>
}
