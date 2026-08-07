import TagSettings from "discourse/components/tag-settings";

export default <template>
  <TagSettings
    @tag={{@model}}
    @selectedTab={{@controller.selectedTab}}
    @parentParams={{@controller.parentParams}}
  />
</template>
