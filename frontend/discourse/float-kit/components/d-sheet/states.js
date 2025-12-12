/**
 * Guard name constants for state machine transitions.
 * Use these instead of string literals to prevent typos.
 *
 * @type {Object<string, string>}
 */
export const GUARD_NAMES = {
  IS_CLOSED: "isClosed",
  IS_CLOSED_AND_SKIP_OPENING: "isClosedAndSkipOpening",
  NOT_SKIP_OPENING: "notSkipOpening",
  NOT_SKIP_CLOSING: "notSkipClosing",
  SKIP_OPENING: "skipOpening",
  SKIP_CLOSING: "skipClosing",
  IS_SAFE_TO_UNMOUNT: "isSafeToUnmount",
  IS_SAFE_TO_UNMOUNT_AND_NOT_SKIP_OPENING: "isSafeToUnmountAndNotSkipOpening",
};

/**
 * Position machine tracks stacking position per sheet.
 *
 * States:
 * - out: Sheet is closed/not visible
 * - front-opening: Sheet is topmost, opening animation in progress
 * - front-idle: Sheet is topmost, fully open
 * - front-closing: Sheet is topmost, closing animation in progress
 * - covered-going-down: Sheet is being covered by another sheet opening above
 * - covered-idle: Sheet is covered by another sheet
 * - covered-going-up: Sheet above is closing, this sheet is uncovering
 * - covered-indeterminate: Temporary state to determine final position
 *
 * This machine coordinates with the staging machine to prevent animation conflicts
 * when opening nested sheets during parent animations.
 */
export const POSITION_STATES = {
  initial: "out",
  states: {
    out: {
      on: {
        READY_TO_GO_FRONT: [
          {
            guard: GUARD_NAMES.SKIP_OPENING,
            target: "front-idle",
          },
          {
            target: "front-opening",
          },
        ],
      },
    },
    "front-opening": {
      on: {
        NEXT: "front-idle",
        GO_OUT: "out",
      },
    },
    "front-idle": {
      on: {
        READY_TO_GO_DOWN: [
          {
            guard: GUARD_NAMES.SKIP_OPENING,
            target: "covered-idle",
          },
          {
            target: "covered-going-down",
          },
        ],
        READY_TO_GO_OUT: "front-closing",
        GO_OUT: "out",
      },
    },
    "front-closing": {
      on: {
        NEXT: "out",
      },
    },
    "covered-going-down": {
      on: {
        NEXT: "covered-idle",
        GOTO_FRONT_IDLE: "front-idle",
      },
    },
    "covered-idle": {
      on: {
        READY_TO_GO_DOWN: [
          {
            guard: GUARD_NAMES.SKIP_OPENING,
            target: "covered-idle",
          },
          {
            target: "covered-going-down",
          },
        ],
        READY_TO_GO_UP: "covered-going-up",
        GO_UP: "covered-indeterminate",
        GOTO_FRONT_IDLE: "front-idle",
      },
    },
    "covered-going-up": {
      on: {
        NEXT: "covered-indeterminate",
        GOTO_FRONT_IDLE: "front-idle",
      },
    },
    "covered-indeterminate": {
      on: {
        GOTO_COVERED_IDLE: "covered-idle",
        GOTO_FRONT_IDLE: "front-idle",
      },
    },
  },
};

/**
 * Staging machine tracks animation state separately from lifecycle.
 * This allows the sheet to stay in "open" state while animations run.
 */
export const STAGING_STATES = {
  initial: "none",
  states: {
    none: {
      on: {
        OPEN: [
          {
            guard: GUARD_NAMES.IS_SAFE_TO_UNMOUNT_AND_NOT_SKIP_OPENING,
            target: "opening",
          },
          { guard: GUARD_NAMES.IS_SAFE_TO_UNMOUNT, target: "open" },
        ],
        OPEN_PREPARED: "opening",
        ACTUALLY_CLOSE: { guard: GUARD_NAMES.NOT_SKIP_CLOSING, target: "closing" },
        ACTUALLY_STEP: "stepping",
        GO_DOWN: [
          { guard: GUARD_NAMES.NOT_SKIP_OPENING, target: "going-down" },
          { target: "go-down" },
        ],
        GO_UP: "going-up",
      },
    },
    opening: { on: { NEXT: "none" } },
    open: { on: { NEXT: "none" } },
    stepping: { on: { NEXT: "none" } },
    closing: { on: { NEXT: "none" } },
    "going-down": { on: { NEXT: "none" } },
    "go-down": { on: { NEXT: "none" } },
    "going-up": { on: { NEXT: "none" } },
  },
};

/**
 * Main sheet state machine managing lifecycle.
 * Uses nested states in "closed" to handle pending/safe-to-unmount distinction.
 */
export const SHEET_STATES = {
  initial: "closed.safe-to-unmount",
  states: {
    closed: {
      initial: "safe-to-unmount",
      on: { OPEN: "preparing-opening" },
      states: {
        "safe-to-unmount": {},
        pending: {
          on: {
            OPEN: [
              {
                guard: GUARD_NAMES.SKIP_OPENING,
                target: "closed.flushing-to-preparing-open",
              },
              { target: "closed.flushing-to-preparing-opening" },
            ],
            FLUSH_COMPLETE: "closed.safe-to-unmount",
          },
        },
        "flushing-to-preparing-opening": {
          on: { FLUSH_COMPLETE: "preparing-opening" },
        },
        "flushing-to-preparing-open": { on: { FLUSH_COMPLETE: "preparing-open" } },
      },
    },
    "preparing-opening": { on: { PREPARED: "opening" } },
    "preparing-open": { on: { PREPARED: "open" } },
    opening: { on: { ANIMATION_COMPLETE: "open" } },
    open: {
      on: {
        CLOSE: "closing",
        STEP: "open",
        SWIPE_OUT: "closed.pending",
      },
      machines: [
        {
          name: "scroll",
          initial: "ended",
          states: {
            ended: { on: { SCROLL_START: "ongoing" } },
            ongoing: { on: { SCROLL_END: "ended" } },
          },
        },
        {
          name: "move",
          initial: "ended",
          states: {
            ended: { on: { MOVE_START: "ongoing" } },
            ongoing: { on: { MOVE_END: "ended" } },
          },
        },
        {
          name: "swipe",
          initial: "unstarted",
          states: {
            unstarted: { on: { SWIPE_START: "ongoing" } },
            ongoing: { on: { SWIPE_END: "ended" } },
            ended: { on: { SWIPE_START: "ongoing", SWIPE_RESET: "unstarted" } },
          },
        },
      ],
    },
    closing: { on: { ANIMATION_COMPLETE: "closed.pending" } },
  },
};
