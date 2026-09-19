import TagSettings from "discourse/components/tag-settings";

export default <template>
  <TagSettings
    @parentParams={{@controller.parentParams}}
    @selectedTab={{@controller.selectedTab}}
    @tag={{@model}}
  />
</template>
