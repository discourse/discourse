import PostMenu from "discourse/components/post/menu";

export default <template>
  <PostMenu
    @canCreatePost={{true}}
    @post={{@post}}
    @showFlags={{true}}
    @showLogin={{true}}
    @showReadIndicator={{true}}
    @toggleLike={{true}}
  />
</template>
