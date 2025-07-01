import Component from "@glimmer/component";

export default class ReviewableItem extends Component {
  get reviewable() {
    return this.args.reviewable;
  }

  <template>
    <div class="review-container">
      {{this.reviewable.type}}
    </div>
  </template>
}
