const AccessibilityLiveRegions = <template>
  <div
    id="a11y-announcements-polite"
    class="sr-only"
    role="status"
    aria-live="polite"
    aria-atomic="true"
  >{{@politeMessage}}</div>
  <div
    id="a11y-announcements-assertive"
    class="sr-only"
    role="alert"
    aria-live="assertive"
    aria-atomic="true"
  >{{@assertiveMessage}}</div>
</template>;

export default AccessibilityLiveRegions;
