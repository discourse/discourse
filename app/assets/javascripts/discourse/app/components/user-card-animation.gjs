import Component from "@glimmer/component";

export default class UserCardAnimation extends Component {
  <template>
    <div class="d-user-card__header d-user-card__placeholder-animation">
    </div>
    <div class="d-user-card__main-content">
      <div class="d-user-card__main-content-top">
        <div class="d-user-card__id">
          <span
            class="card-avatar-placeholder d-user-card__placeholder-animation"
          >
          </span>
          <span class="d-user-card__id-titles">
            <div
              class="d-user-card__titles-top d-user-card__placeholder-animation"
            >
            </div>
            <div
              class="d-user-card__titles-bottom d-user-card__placeholder-animation"
            >
            </div>
          </span>
        </div>
        <div class="d-user-card__user-content">
          <div
            class="d-user-card__custom-fields .card-row .d-user-card__placeholder-animation"
          >
          </div>
        </div>
      </div>
      <div class="d-user-card__main-content-bottom">
        <div class="card-row d-user-card__placeholder-animation"></div>
        <div class="card-row d-user-card__placeholder-animation"></div>
        <div class="card-row d-user-card__placeholder-animation"></div>
      </div>
    </div>
  </template>
}
