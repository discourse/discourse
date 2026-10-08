import Header from "discourse/components/header";

export default <template>
  <div class="d-header-wrap" inert>
    <Header
      @sidebarEnabled={{@sidebarEnabled}}
      @topicInfo={{@topic}}
      @topicInfoVisible={{true}}
    />
  </div>
</template>
