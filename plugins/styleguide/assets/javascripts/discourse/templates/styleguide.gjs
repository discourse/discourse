export default <template>
  {{! The section navigation is a sidebar panel that takes over the main sidebar for the length
  of this route. See the styleguide-sidebar service. }}
  <section class="styleguide">
    <section class="styleguide-contents">
      {{outlet}}
    </section>
  </section>
</template>
