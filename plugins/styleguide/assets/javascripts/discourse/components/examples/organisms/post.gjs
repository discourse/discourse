import Post from "discourse/components/post";

export default <template>
  <Post @post={{@post}} @canCreatePost={{true}} />
</template>
