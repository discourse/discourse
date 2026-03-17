import { trustHTML } from "@ember/template";

export default <template>
  <div class="container">
    {{trustHTML @controller.model}}
  </div>
</template>
