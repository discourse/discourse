import DButton from "discourse/ui-kit/d-button";

const SidebarSectionHeader = <template>
  {{#if @collapsable}}
    <DButton
      aria-controls={{@sidebarSectionContentId}}
      aria-expanded={{if @isExpanded "true" "false"}}
      class="sidebar-section-header sidebar-section-header-collapsable btn-transparent"
      data-sidebar-keep-open
      @action={{@toggleSectionDisplay}}
      @forwardEvent={{true}}
      @title="sidebar.toggle_section"
    >
      {{yield}}
    </DButton>
  {{else}}
    <span class="sidebar-section-header">
      {{yield}}
    </span>
  {{/if}}
</template>;

export default SidebarSectionHeader;
