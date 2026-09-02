import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import PanelDockSingleExample from "../../examples/organisms/panel-dock/single";
import panelDockSingleSource from "../../examples/organisms/panel-dock/single?source=file";
import PanelDockTabbedExample from "../../examples/organisms/panel-dock/tabbed";
import panelDockTabbedSource from "../../examples/organisms/panel-dock/tabbed?source=file";

export default <template>
  <StyleguideExample
    @title="<DPanelDock> — a tabbed dock"
    @code={{panelDockTabbedSource}}
    @description="A panel docked to an edge of the viewport that stays open while the page behind it is used. Each tab names a component, and the dock derives the strip, the keyboard cursor and the ARIA pairing from that list. It is deliberately not a modal: nothing is dimmed, focus is not trapped, and the page underneath keeps its clicks."
  >
    <:tryThis>
      Open it, then keep using the styleguide behind it. Move it between edges
      with the picker in its header, drag the edge nearest the page to resize
      it, and reload — it comes back where and how you left it, because the
      layout is stored under the panel's context.
    </:tryThis>
    <:default>
      <PanelDockTabbedExample />
    </:default>
    <:note>
      The dock sets no z-index of its own: where it belongs in the stacking
      order depends on what it is being used for, so the caller styles that.
      These examples do it in the styleguide's own stylesheet.
    </:note>
  </StyleguideExample>

  <StyleguideExample
    @title="<DPanelDock> — a single panel"
    @code={{panelDockSingleSource}}
    @description="With one tab there is no strip. A lone tab is not a choice, so announcing a selection nobody can change would be noise; the header row stays for the close button and the panel takes the rest."
  >
    <:tryThis>
      Open this one alongside the tabbed dock above. Two docks with different
      contexts are independent — separate positions, separate stored layouts —
      and neither blocks the other or the page.
    </:tryThis>
    <:default>
      <PanelDockSingleExample />
    </:default>
  </StyleguideExample>
</template>
