import Header from "discourse/components/header";

export default <template>
  <div inert class="d-header-wrap">
    <Header
      @sidebarEnabled={{@sidebarEnabled}}
      @topicInfo={{@topic}}
      @topicInfoVisible={{true}}
    />
  </div>
</template>
