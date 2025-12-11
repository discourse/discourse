import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class RewindCallout extends Component {
  @service router;
  @service rewind;

  get showCallout() {
    return (
      this.rewind.active && !this.rewind.dismissed && !this.rewind.disabled
    );
  }

  @action
  openRewind() {
    this.rewind.dismiss();
    this.router.transitionTo("/my/activity/rewind");
  }

  <template>
    {{#if this.showCallout}}
      <div class="rewind-callout__container">
        <DButton
          @action={{this.openRewind}}
          class="rewind-callout btn-transparent"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 515.48 76.72">
            <path d="M0 0h515.48v76.72H0z" style="fill:#faf7e4" />
            <path
              d="M42.27 12.67c-12.8 0-23.58 10.38-23.58 23.18v24l23.57-.02c12.8 0 23.18-10.78 23.18-23.58S55.05 12.67 42.26 12.67z"
              style="fill:#010101"
            />
            <path
              d="M42.51 21.64c-7.94 0-14.37 6.44-14.36 14.38 0 2.39.6 4.73 1.73 6.83l-2.6 8.36 9.34-2.11a14.36 14.36 0 0 0 15.85-2.73 14.371 14.371 0 0 0-9.94-24.74h-.02Z"
              style="fill:#fcf6b2"
            />
            <path
              d="M53.75 44.9a14.356 14.356 0 0 1-17.13 4.18l-9.34 2.14 9.5-1.12c6.3 3.69 14.37 2.07 18.75-3.77s3.68-14.04-1.62-19.06c3.98 5.22 3.92 12.49-.16 17.63"
              style="fill:#29abe2"
            />
            <path
              d="M52.94 42.17c-3.52 5.55-10.35 7.99-16.6 5.95l-9.06 3.1 9.34-2.11c6.65 3 14.49.54 18.24-5.72s2.2-14.34-3.59-18.77c4.51 4.78 5.2 12.01 1.68 17.55Z"
              style="fill:#10a94d"
            />
            <path
              d="M30.74 43.17c-2.6-6.27-.46-13.51 5.14-17.35S49 22.58 53.92 27.26c-4.55-5.98-12.94-7.44-19.24-3.35s-8.39 12.34-4.8 18.93l-2.6 8.36 3.46-8.04Z"
              style="fill:#f15f25"
            />
            <path
              d="M29.88 42.85a14.36 14.36 0 0 1 3.31-17.77 14.35 14.35 0 0 1 18.07-.46c-5.16-5.43-13.63-5.99-19.45-1.28-5.83 4.71-7.05 13.11-2.82 19.29l-1.71 8.59zM181.65 0l71.41 76.72h34.22L215.88 0z"
              style="fill:#d0222b"
            />
            <path
              d="m215.88 0 71.4 76.72h34.23L250.11 0z"
              style="fill:#f15f25"
            />
            <path
              d="m250.11 0 71.4 76.72h34.23L284.33 0z"
              style="fill:#fcf6b2"
            />
            <path
              d="m284.33 0 71.41 76.72h34.22L318.56 0z"
              style="fill:#10a94d"
            />
            <path
              d="m318.56 0 71.4 76.72h34.23L352.79 0z"
              style="fill:#29abe2"
            />

            <text
              x="108"
              y="22"
              text-anchor="middle"
              dominant-baseline="middle"
              style="font-size: 20px; transform: skewX(15deg); fill: #010101; letter-spacing: .025em;"
            >{{i18n "discourse_rewind.title"}}</text>

            <text
              x="115"
              y="50"
              text-anchor="middle"
              dominant-baseline="middle"
              style="font-size: 32px; font-weight: bold; fill: #010101;"
            >{{this.rewind.fetchRewindYear}}</text>

          </svg>

          <span class="btn no-text --special-kbd">
            {{icon "play"}}
          </span>

        </DButton>
      </div>
    {{/if}}
  </template>
}
