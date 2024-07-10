import DButton from "discourse/components/d-button";

const SidebarSectionHeader = <template>
  {{#if @collapsable}}
    <DButton
      @title="sidebar.toggle_section"
      @action={{@toggleSectionDisplay}}
      aria-controls={{@sidebarSectionContentId}}
      aria-expanded={{if @isExpanded "true" "false"}}
      class="sidebar-section-header sidebar-section-header-collapsable btn-transparent"
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
