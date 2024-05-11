import ApiSections from "./api-sections";

const SidebarApiPanels = <template>
  <div class="sidebar-sections">
    <ApiSections @collapsable={{@collapsableSections}} />
  </div>
</template>;

export default SidebarApiPanels;
