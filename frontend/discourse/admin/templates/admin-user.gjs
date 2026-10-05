import bodyClass from "discourse/helpers/body-class";

export default <template>
  {{#if @controller.arrivedFromProfile}}
    {{bodyClass "user-nav-from-profile"}}
  {{/if}}

  <section>{{outlet}}</section>
</template>
