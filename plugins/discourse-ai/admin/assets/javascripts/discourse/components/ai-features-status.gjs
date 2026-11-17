/**
 * @param {"on" | "off" | "setup"} status
 * @param {string} label
 */
const AiFeaturesStatus = <template>
  <span class="ai-features-status --{{@status}}" data-status={{@status}}>
    <span class="ai-features-status__dot"></span>
    {{@label}}
  </span>
</template>;

export default AiFeaturesStatus;
