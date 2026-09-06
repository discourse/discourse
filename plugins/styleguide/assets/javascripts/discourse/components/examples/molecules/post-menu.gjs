import PostMenu from "discourse/components/post/menu";

export default <template>
  <PostMenu
    @post={{@post}}
    @canCreatePost={{true}}
    @showFlags={{true}}
    @showLogin={{true}}
    @showReadIndicator={{true}}
    @toggleLike={{true}}
  />
</template>
