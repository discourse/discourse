import StyleguidePageHeader from "discourse/plugins/styleguide/discourse/components/styleguide-page-header";

export default <template>
  <StyleguidePageHeader />

  <section class="styleguide">
    <section class="styleguide-contents">
      {{outlet}}
    </section>
  </section>
</template>
