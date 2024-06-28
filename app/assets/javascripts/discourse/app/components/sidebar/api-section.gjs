import Section from "./section";
import SectionLink from "./section-link";

const SidebarApiSection = <template>
  {{#if @section.filtered}}
    <Section
      @sectionName={{@section.name}}
      @headerLinkText={{@section.text}}
      @headerLinkTitle={{@section.title}}
      @headerActionsIcon={{@section.actionsIcon}}
      @headerActions={{@section.actions}}
      @willDestroy={{@section.willDestroy}}
      @collapsable={{@collapsable}}
      @displaySection={{@section.displaySection}}
      @hideSectionHeader={{@section.hideSectionHeader}}
      @collapsedByDefault={{@section.collapsedByDefault}}
    >
      {{#each @section.filteredLinks key="name" as |link|}}
        <SectionLink
          @linkName={{link.name}}
          @linkClass={{link.classNames}}
          @route={{link.route}}
          @model={{link.model}}
          @query={{link.query}}
          @models={{link.models}}
          @href={{link.href}}
          @title={{link.title}}
          @contentCSSClass={{link.contentCSSClass}}
          @prefixColor={{link.prefixColor}}
          @prefixBadge={{link.prefixBadge}}
          @prefixType={{link.prefixType}}
          @prefixValue={{link.prefixValue}}
          @prefixCSSClass={{link.prefixCSSClass}}
          @suffixType={{link.suffixType}}
          @suffixValue={{link.suffixValue}}
          @suffixCSSClass={{link.suffixCSSClass}}
          @hoverType={{link.hoverType}}
          @hoverValue={{link.hoverValue}}
          @hoverAction={{link.hoverAction}}
          @hoverTitle={{link.hoverTitle}}
          @currentWhen={{link.currentWhen}}
          @didInsert={{link.didInsert}}
          @willDestroy={{link.willDestroy}}
          @content={{link.text}}
          @contentComponent={{component
            link.contentComponent
            status=link.contentComponentArgs
          }}
        />
      {{/each}}
    </Section>
  {{/if}}
</template>;

export default SidebarApiSection;
