import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton
    class="icon btn-flat"
    id="toggle-context-panel"
    @action={{@toggle}}
    @ariaControls={{if @expanded "page-shell-context"}}
    @ariaExpanded={{@expanded}}
    @ariaLabel="page_shell.context"
    @icon="table-columns"
    @title={{if
      @expanded
      "page_shell.hide_context"
      "page_shell.expand_context"
    }}
  />
</template>
