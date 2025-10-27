import { htmlSafe } from "@ember/template";

export default <template>
  <div class="container">
    {{htmlSafe @controller.model}}
  </div>
</template>
