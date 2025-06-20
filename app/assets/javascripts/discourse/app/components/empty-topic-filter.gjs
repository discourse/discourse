import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import basePath from "discourse/helpers/base-path";
import htmlSafe from "discourse/helpers/html-safe";
import { emojiUnescape } from "discourse/lib/text";
import { i18n } from "discourse-i18n";

export default class EmptyTopicFilter extends Component {
  @service currentUser;

  get educationText() {
    if (this.args.unreadFilter) {
      return i18n("topics.none.education.unread");
    } else if (this.args.newFilter) {
      if (this.currentUser.new_new_view_enabled) {
        return i18n("topics.none.education.new_new");
      } else {
        return i18n("topics.none.education.new");
      }
    }
  }

  <template>
    <div class="empty-topic-filter">

      <div class="empty-topic-filter__image">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 285 248"
          fill="none"
        >
          <g id="no-unreads">
            <g id="rocket">
              <path
                id="rocket-path"
                d="M83.267 188.281C67.7477 172.762 77.7879 123.902 56.7848 123.902C17.4326 130.461 -8.19523 61.6111 6.6608 29.3877"
                stroke="var(--tertiary)"
                stroke-width="1.82636"
                stroke-linecap="round"
                stroke-dasharray="2.74 3.65"
              />
              <g id="rocket_2">
                <rect
                  x="1"
                  y="7.34277"
                  width="21.9163"
                  height="21.9163"
                  rx="10.9582"
                  transform="rotate(-16.8237 1 7.34277)"
                  fill="var(--primary-low)"
                />
                <path
                  id="icon"
                  d="M12.0983 20.9751L10.4441 20.089C10.0172 19.8604 9.74562 19.4058 9.71987 18.877C9.73129 18.4711 9.75891 17.9708 9.79033 17.3352L5.48813 18.6361C5.11937 18.7476 4.74203 18.6828 4.47902 18.4046C4.18743 18.1797 4.07593 17.8109 4.18169 17.4212L5.22206 13.1713C5.48216 12.1089 6.29207 11.2379 7.3164 10.9282L10.7172 9.89989C10.7496 9.71122 10.7944 9.56352 10.8677 9.36246C12.7285 3.38879 17.6776 1.71344 20.8012 1.39505C21.3176 1.32833 21.7979 1.58559 22.0285 2.05249C23.4941 4.82912 24.8417 9.87742 20.8998 14.7363C20.7731 14.9088 20.634 15.0403 20.5359 15.1594L21.5641 18.5602C21.8739 19.5845 21.5976 20.7413 20.8572 21.5465L17.8958 24.7674C17.6176 25.0304 17.2612 25.1829 16.9124 25.0647C16.5351 24.9999 16.2721 24.7217 16.1606 24.3529L14.835 19.9688C14.2823 20.3595 13.8402 20.6721 13.5086 20.9065C13.1074 21.2067 12.5376 21.2448 12.0983 20.9751ZM18.7518 9.25924C19.6532 8.98668 20.1801 8.06713 19.8952 7.12475C19.6226 6.22333 18.6621 5.70882 17.7607 5.98138C16.8183 6.26632 16.3448 7.21446 16.6173 8.11587C16.9023 9.05825 17.8094 9.54419 18.7518 9.25924Z"
                  fill="var(--tertiary)"
                />
              </g>
            </g>
            <g id="files">
              <g id="bg-file">
                <rect
                  id="Rectangle 18"
                  x="29.9023"
                  y="24.3738"
                  width="136.064"
                  height="162.546"
                  rx="1.36977"
                  transform="rotate(-7.6929 29.9023 24.3738)"
                  fill="var(--tertiary-100)"
                  stroke="var(--tertiary-high)"
                  stroke-width="0.913181"
                />
                <rect
                  id="Rectangle 19"
                  x="51.8054"
                  y="34.2859"
                  width="136.064"
                  height="162.546"
                  rx="1.36977"
                  transform="rotate(-5.70639 51.8054 34.2859)"
                  fill="var(--tertiary-100)"
                  stroke="var(--tertiary-high)"
                  stroke-width="0.913181"
                />
              </g>
              <g id="top-file">
                <g id="top-file-bg">
                  <path
                    id="Rectangle 20"
                    d="M89.1055 41.8417L204.031 50.6123C204.308 50.6335 204.572 50.7377 204.787 50.9109L204.875 50.9895L221.594 67.0239C221.851 67.2697 222 67.604 222.015 67.9549L222.012 68.1055L212.218 212.007C212.166 212.763 211.511 213.333 210.755 213.28L77.7588 203.98C77.0043 203.927 76.4358 203.273 76.4886 202.518L87.6353 43.1124L87.652 42.9726C87.763 42.3314 88.3142 41.8553 88.9647 41.8387L89.1055 41.8417Z"
                    fill="var(--secondary)"
                    stroke="var(--tertiary-high)"
                    stroke-width="0.913181"
                  />
                  <path
                    id="Vector 11"
                    d="M204.263 50.848L202.894 66.34L221.613 67.742"
                    stroke="var(--tertiary-high)"
                    stroke-width="0.913181"
                  />
                </g>
                <g id="lines">
                  <path
                    id="Line 9"
                    d="M97.8594 67.9902L169.124 72.9735"
                    stroke="var(--primary-low)"
                    stroke-width="4"
                    stroke-linecap="round"
                  />
                  <path
                    id="Line 10"
                    d="M96.0391 84.3369L185.541 90.5955"
                    stroke="var(--primary-low)"
                    stroke-width="4"
                    stroke-linecap="round"
                  />
                  <path
                    id="Line 14"
                    d="M92.3721 140.227L160.912 145.019"
                    stroke="var(--primary-low)"
                    stroke-width="4"
                    stroke-linecap="round"
                  />
                  <path
                    id="Line 11"
                    d="M95.1338 102.51L184.635 108.768"
                    stroke="var(--primary-low)"
                    stroke-width="4"
                    stroke-linecap="round"
                  />
                  <path
                    id="Line 15"
                    d="M93.3525 120.959L195.581 128.107"
                    stroke="var(--primary-low)"
                    stroke-width="4"
                    stroke-linecap="round"
                  />
                </g>
              </g>
            </g>
            <g id="overflow-text">
              <path
                id="Line 16"
                d="M227.575 93.8076L272.466 96.9467"
                stroke="var(--tertiary-100)"
                stroke-width="4"
                stroke-linecap="round"
              />
              <path
                id="Line 17"
                d="M225.76 111.087L282.621 115.063"
                stroke="var(--tertiary-100)"
                stroke-width="4"
                stroke-linecap="round"
              />
              <path
                id="Line 18"
                d="M224.82 129.087L269.711 132.226"
                stroke="var(--tertiary-100)"
                stroke-width="4"
                stroke-linecap="round"
              />
              <path
                id="Star 2"
                d="M268.849 136.566C268.849 136.566 270.219 139.757 271.588 141.225C273.066 142.809 275.698 143.415 275.698 143.415C275.698 143.415 273.066 144.11 271.588 145.694C270.219 147.163 268.849 150.264 268.849 150.264C268.849 150.264 267.479 147.163 266.109 145.694C264.632 144.11 262 143.415 262 143.415C262 143.415 264.848 142.809 266.326 141.225C267.695 139.757 268.849 136.566 268.849 136.566Z"
                fill="var(--tertiary)"
              />
              <path
                id="Star 3"
                d="M237.62 77.0838C237.62 77.0838 239.486 78.8152 240.841 79.3924C242.303 80.015 244.247 79.6388 244.247 79.6388C244.247 79.6388 242.689 80.8868 242.17 82.3881C241.688 83.7799 241.692 86.2662 241.692 86.2662C241.692 86.2662 239.852 84.5943 238.497 84.0171C237.035 83.3945 235.065 83.7113 235.065 83.7113C235.065 83.7113 236.794 82.4584 237.313 80.9571C237.795 79.5653 237.62 77.0838 237.62 77.0838Z"
                fill="var(--tertiary-high)"
              />
              <path
                id="Star 4"
                d="M279.086 132.585C279.086 132.585 279.014 134.343 279.319 135.314C279.649 136.362 280.719 137.214 280.719 137.214C280.719 137.214 279.364 136.956 278.342 137.357C277.394 137.729 276.09 138.848 276.09 138.848C276.09 138.848 276.142 137.13 275.837 136.159C275.508 135.112 274.456 134.218 274.456 134.218C274.456 134.218 275.891 134.564 276.913 134.163C277.861 133.791 279.086 132.585 279.086 132.585Z"
                fill="var(--tertiary-high)"
              />
            </g>
            <ellipse
              id="shadow"
              cx="141.254"
              cy="241.246"
              rx="95.4274"
              ry="6.39227"
              fill="var(--primary-low)"
            />
            <g id="star">
              <g id="Group 18">
                <g id="Group 17">
                  <line
                    id="Line 19"
                    x1="58.8772"
                    y1="199.759"
                    x2="56.0508"
                    y2="206.288"
                    stroke="var(--tertiary)"
                    stroke-width="0.913181"
                  />
                  <line
                    id="Line 20"
                    x1="53.7239"
                    y1="211.666"
                    x2="50.8975"
                    y2="218.196"
                    stroke="var(--tertiary)"
                    stroke-width="0.913181"
                  />
                </g>
              </g>
              <g id="Group 21">
                <g id="Group 17_2">
                  <line
                    id="Line 19_2"
                    x1="63.9768"
                    y1="205.522"
                    x2="57.361"
                    y2="208.141"
                    stroke="var(--tertiary)"
                    stroke-width="0.913181"
                  />
                  <line
                    id="Line 20_2"
                    x1="51.9124"
                    y1="210.298"
                    x2="45.2966"
                    y2="212.916"
                    stroke="var(--tertiary)"
                    stroke-width="0.913181"
                  />
                </g>
              </g>
              <g id="Group 20">
                <g id="Group 17_3">
                  <line
                    id="Line 19_3"
                    x1="51.1972"
                    y1="199.286"
                    x2="53.8159"
                    y2="205.902"
                    stroke="var(--tertiary)"
                    stroke-width="0.913181"
                  />
                  <line
                    id="Line 20_3"
                    x1="55.9727"
                    y1="211.351"
                    x2="58.5914"
                    y2="217.966"
                    stroke="var(--tertiary)"
                    stroke-width="0.913181"
                  />
                </g>
              </g>
              <g id="Group 19">
                <g id="Group 17_4">
                  <line
                    id="Line 19_4"
                    x1="45.4316"
                    y1="204.386"
                    x2="51.9614"
                    y2="207.212"
                    stroke="var(--tertiary)"
                    stroke-width="0.913181"
                  />
                  <line
                    id="Line 20_4"
                    x1="57.3388"
                    y1="209.539"
                    x2="63.8685"
                    y2="212.365"
                    stroke="var(--tertiary)"
                    stroke-width="0.913181"
                  />
                </g>
              </g>
            </g>
            <g id="checkmark">
              <path
                id="Vector 13"
                d="M219.714 224.808C230.759 222.047 241.672 204.355 243.703 192.847C244.616 173.67 240.051 162.255 218.591 151.754"
                stroke="var(--tertiary)"
                stroke-width="1.82636"
                stroke-linecap="round"
                stroke-dasharray="2.74 3.65"
              />
              <g id="check">
                <rect
                  x="182.457"
                  y="140.796"
                  width="73.0545"
                  height="73.0545"
                  rx="36.5272"
                  transform="rotate(21.1652 182.457 140.796)"
                  fill="var(--secondary)"
                />
                <path
                  id="icon_2"
                  d="M169.231 174.956C176.495 156.195 197.588 146.766 216.483 154.082C235.244 161.346 244.621 182.572 237.357 201.333C230.042 220.228 208.867 229.472 190.106 222.208C171.211 214.893 161.915 193.851 169.231 174.956ZM220.863 188.215C222.893 187.318 223.769 185.056 222.872 183.025C221.975 180.995 219.713 180.119 217.683 181.016L197.748 189.823L194.027 181.65C193.13 179.62 190.868 178.744 188.838 179.641C186.808 180.538 185.932 182.8 186.829 184.83L192.048 196.643C192.944 198.673 195.206 199.549 197.237 198.652L220.863 188.215Z"
                  fill="var(--tertiary)"
                />
              </g>
            </g>
          </g>
        </svg>
      </div>

      <div class="empty-topic-filter__text">
        <p>{{this.educationText}}</p>
      </div>

      <div class="empty-topic-filter__cta">
        <DButton
          @route="discovery.latest"
          @label="topic.browse_latest_topics"
          class="btn-primary"
        />

        <div class="empty-topic-filter__preferences-hint">
          {{htmlSafe (emojiUnescape ":bulb:")}}
          {{htmlSafe
            (i18n
              "topics.none.education.topic_tracking_preferences"
              basePath=(basePath)
            )
          }}
        </div>
      </div>
    </div>
  </template>
}
