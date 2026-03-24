import BoostsStream from "../../components/boosts-stream";

export default <template>
  <BoostsStream
    @boosts={{@model.boosts}}
    @canLoadMore={{@model.canLoadMore}}
    @username={{@model.username}}
    @boostsUrl={{@model.boostsUrl}}
  />
</template>
