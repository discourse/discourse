import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import TagSectionLink from "discourse/lib/sidebar/user/tags-section/tag-section-link";
import { i18n } from "discourse-i18n";
import AllTagsSectionLink from "../common/all-tags-section-link";
import Section from "../section";
import SectionLink from "../section-link";

export default class SidebarAnonymousTagsSection extends Component {
  @service router;
  @service topicTrackingState;
  @service site;

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
        @sectionName="tags"
        @headerLinkText={{i18n "sidebar.sections.tags.header_link_text"}}
        @collapsable={{@collapsable}}
      >

        {{#each this.sectionLinks as |sectionLink|}}
          <SectionLink
            @route={{sectionLink.route}}
            @content={{sectionLink.text}}
            @title={{sectionLink.title}}
            @currentWhen={{sectionLink.currentWhen}}
            @prefixType={{sectionLink.prefixType}}
            @prefixValue={{sectionLink.prefixValue}}
            @prefixColor={{sectionLink.prefixColor}}
            @models={{sectionLink.models}}
            data-tag-name={{sectionLink.tagName}}
          />
        {{/each}}

        <AllTagsSectionLink />
      </Section>
    {{/if}}
  </template>
}
