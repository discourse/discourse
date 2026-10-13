import Post from "discourse/components/post";

export default <template>
  <Post @canCreatePost={{true}} @post={{@post}} />
</template>
