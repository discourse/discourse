import BoostsList from "./boosts-list";

const BoostsPostMenu = <template>
  {{#unless @outletArgs.post.deleted}}
    <div class="discourse-boosts__post-menu">
      <BoostsList @post={{@outletArgs.post}} />
    </div>
  {{/unless}}
</template>;

export default BoostsPostMenu;
