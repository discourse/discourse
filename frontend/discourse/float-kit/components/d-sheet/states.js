/**
 * Guard name constants for state machine transitions.
 * Use these instead of string literals to prevent typos.
 *
 * @type {Object<string, string>}
 */
export const GUARD_NAMES = {
  NOT_SKIP_CLOSING: "notSkipClosing",
  SKIP_OPENING: "skipOpening",
  SKIP_CLOSING: "skipClosing",
};

/**
 * Guard functions for state machine transitions.
 * Each guard receives (message, messageContext, machineContext) and returns a boolean.
 *
 * @type {Object<string, function(Object, Object, Object): boolean>}
 */
export const GUARDS = {
  [GUARD_NAMES.NOT_SKIP_CLOSING]: (msg, msgCtx, machineCtx) =>
    !machineCtx.skipClosing && !msgCtx.skipClosing,
  [GUARD_NAMES.SKIP_OPENING]: (msg, msgCtx, machineCtx) =>
    machineCtx.skipOpening || msgCtx.skipOpening,
  [GUARD_NAMES.SKIP_CLOSING]: (msg, msgCtx, machineCtx) =>
    machineCtx.skipClosing || msgCtx.skipClosing,
};

/**
 * Position machine tracks stacking position per sheet.
 * Uses nested machines for `front` and `covered` states matching Silk's architecture.
 *
 * States:
 * - out: Sheet is closed/not visible
 * - front: Sheet is topmost (with nested status machine)
 *   - status:opening: Opening animation in progress
 *   - status:idle: Fully open
 *   - status:closing: Closing animation in progress
 * - covered: Sheet is covered by another sheet (with nested status machine)
 *   - status:going-down: Being covered by another sheet opening above
 *   - status:idle: Covered and stable
 *   - status:going-up: Sheet above is closing, this sheet is uncovering
 *   - status:indeterminate: Temporary state to determine final position
 *   - status:come-back: Immediate transition back to idle
 *
 * This machine coordinates with the animation state machine to prevent animation conflicts
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
            target: "front.status:idle",
          },
          {
            target: "front",
          },
        ],
      },
    },
    front: {
      on: {
        GO_OUT: "out",
      },
      machines: [
        {
          name: "status",
          initial: "opening",
          states: {
            opening: {
              on: {
                NEXT: "idle",
              },
            },
            closing: {
              on: {
                NEXT: "out",
              },
            },
            idle: {
              on: {
                READY_TO_GO_DOWN: [
                  {
                    guard: GUARD_NAMES.SKIP_OPENING,
                    target: "covered.status:idle",
                  },
                  {
                    target: "covered",
                  },
                ],
                READY_TO_GO_OUT: "closing",
              },
            },
          },
        },
      ],
    },
    covered: {
      machines: [
        {
          name: "status",
          initial: "going-down",
          states: {
            "going-down": {
              on: {
                NEXT: "idle",
                GOTO_FRONT_IDLE: "front.status:idle",
              },
            },
            "going-up": {
              on: {
                NEXT: "indeterminate",
                GOTO_FRONT_IDLE: "front.status:idle",
              },
            },
            indeterminate: {
              on: {
                GOTO_COVERED_IDLE: "idle",
                GOTO_FRONT_IDLE: "front.status:idle",
              },
            },
            idle: {
              on: {
                READY_TO_GO_DOWN: [
                  {
                    guard: GUARD_NAMES.SKIP_OPENING,
                    target: "come-back",
                  },
                  {
                    target: "going-down",
                  },
                ],
                READY_TO_GO_UP: "going-up",
                GO_UP: "indeterminate",
                GOTO_FRONT_IDLE: "front.status:idle",
              },
            },
            "come-back": {
              on: {
                "": "idle",
              },
            },
          },
        },
      ],
    },
  },
};


/**
 * Animation state machine tracks which animation is currently in progress.
 * This allows the sheet to stay in "open" state while animations run.
 */
export const ANIMATION_STATES = {
  initial: "none",
  states: {
    none: {
      on: {
        OPEN_PREPARED: "opening",
        ACTUALLY_CLOSE: {
          guard: GUARD_NAMES.NOT_SKIP_CLOSING,
          target: "closing",
        },
        ACTUALLY_STEP: "stepping",
        GO_DOWN: "going-down",
        GO_UP: "going-up",
      },
    },
    opening: { on: { NEXT: "none" } },
    stepping: { on: { NEXT: "none" } },
    closing: { on: { NEXT: "none" } },
    "going-down": { on: { NEXT: "none" } },
    "going-up": { on: { NEXT: "none" } },
  },
};

/**
 * Long-running state machine tracks whether a "long running" operation is in progress.
 * Used to persist outlet styles during scroll-based travel and manage focus.
 *
 * - Set to `true` when: staging becomes "open" or "opening"
 * - Set to `false` when: openness becomes "closed"
 */
export const LONG_RUNNING_STATES = {
  initial: "false",
  states: {
    false: { on: { TO_TRUE: "true" } },
    true: { on: { TO_FALSE: "false" } },
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
        "flushing-to-preparing-open": {
          on: { FLUSH_COMPLETE: "preparing-open" },
        },
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
            ended: {
              on: { SCROLL_START: "ongoing" },
              machines: [
                {
                  name: "afterPaintEffectsRun",
                  initial: "false",
                  states: {
                    false: { on: { OCCURRED: "true" } },
                    true: { on: { RESET: "false" } },
                  },
                },
              ],
            },
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
          silentOnly: true,
          initial: "unstarted",
          states: {
            unstarted: { on: { SWIPE_START: "ongoing" } },
            ongoing: { on: { SWIPE_END: "ended" } },
            ended: { on: { SWIPE_START: "ongoing", SWIPE_RESET: "unstarted" } },
          },
        },
        {
          name: "evaluateCloseMessage",
          silentOnly: true,
          initial: "false",
          states: {
            false: { on: { CLOSE: "true" } },
            true: { on: { CLOSE: "false" } },
          },
        },
        {
          name: "evaluateStepMessage",
          silentOnly: true,
          initial: "false",
          states: {
            false: { on: { STEP: "true" } },
            true: { on: { STEP: "false" } },
          },
        },
      ],
    },
    closing: { on: { ANIMATION_COMPLETE: "closed.pending" } },
  },
};
