/**
 * Guard name constants for state machine transitions.
 * Use these instead of string literals to prevent typos.
 *
 * @type {Object<string, string>}
 */
export const GUARD_NAMES = {
  NOT_SKIP_CLOSING: "notSkipClosing",
  NOT_SKIP_OPENING: "notSkipOpening",
  NOT_SKIP_CLOSING_MSG: "notSkipClosingMsg",
  NOT_SKIP_OPENING_MSG: "notSkipOpeningMsg",
  SKIP_OPENING: "skipOpening",
  SKIP_CLOSING: "skipClosing",
  SAFE_TO_UNMOUNT: "safeToUnmount",
  SAFE_TO_UNMOUNT_AND_NOT_SKIP_OPENING: "safeToUnmountAndNotSkipOpening",
};

/**
 * Guard functions for state machine transitions.
 * Each guard receives (previousStates, message) and returns a boolean.
 * - previousStates: Array of state strings before transition
 * - message: The message object with optional context properties
 *
 * @type {Object<string, function(string[], Object): boolean>}
 */
export const GUARDS = {
  [GUARD_NAMES.NOT_SKIP_CLOSING]: (previousStates, message) =>
    !previousStates.includes("skipClosing:true") && !message.skipClosing,
  [GUARD_NAMES.NOT_SKIP_OPENING]: (previousStates, message) =>
    !previousStates.includes("skipOpening:true") && !message.skipOpening,
  [GUARD_NAMES.NOT_SKIP_CLOSING_MSG]: (previousStates, message) =>
    !message.skipClosing,
  [GUARD_NAMES.NOT_SKIP_OPENING_MSG]: (previousStates, message) =>
    !message.skipOpening,
  [GUARD_NAMES.SKIP_OPENING]: (previousStates, message) =>
    previousStates.includes("skipOpening:true") || message.skipOpening,
  [GUARD_NAMES.SKIP_CLOSING]: (previousStates, message) =>
    previousStates.includes("skipClosing:true") || message.skipClosing,
  [GUARD_NAMES.SAFE_TO_UNMOUNT]: (previousStates) =>
    previousStates.includes("openness:closed.status:safe-to-unmount"),
  [GUARD_NAMES.SAFE_TO_UNMOUNT_AND_NOT_SKIP_OPENING]: (
    previousStates,
    message
  ) =>
    previousStates.includes("openness:closed.status:safe-to-unmount") &&
    !previousStates.includes("skipOpening:true") &&
    !message.skipOpening,
};

/**
 * Sheet machines array for StateMachineGroup.
 * Matches Silk's first tw() call structure.
 */
export const SHEET_MACHINES = [
  {
    name: "staging",
    initial: "none",
    states: {
      none: {
        messages: {
          OPEN: [
            {
              guard: GUARD_NAMES.SAFE_TO_UNMOUNT_AND_NOT_SKIP_OPENING,
              target: "opening",
            },
            {
              guard: GUARD_NAMES.SAFE_TO_UNMOUNT,
              target: "open",
            },
          ],
          OPEN_PREPARED: [
            {
              guard: GUARD_NAMES.NOT_SKIP_OPENING,
              target: "opening",
            },
            {
              target: "open",
            },
          ],
          ACTUALLY_CLOSE: {
            guard: GUARD_NAMES.NOT_SKIP_CLOSING,
            target: "closing",
          },
          ACTUALLY_STEP: "stepping",
          GO_DOWN: [
            {
              guard: GUARD_NAMES.NOT_SKIP_OPENING_MSG,
              target: "going-down",
            },
            {
              target: "go-down",
            },
          ],
          GO_UP: "going-up",
        },
      },
      open: { messages: { NEXT: "none" } },
      opening: { messages: { NEXT: "none" } },
      stepping: { messages: { NEXT: "none" } },
      closing: { messages: { NEXT: "none" } },
      "go-down": { messages: { NEXT: "none" } },
      "going-down": { messages: { NEXT: "none" } },
      "going-up": { messages: { NEXT: "none" } },
    },
  },
  {
    name: "longRunning",
    initial: "false",
    states: {
      false: { messages: { TO_TRUE: "true" } },
      true: { messages: { TO_FALSE: "false" } },
    },
  },
  {
    name: "skipOpening",
    initial: "false",
    states: {
      true: { messages: { TO_FALSE: "false" } },
      false: { messages: { TO_TRUE: "true" } },
    },
  },
  {
    name: "skipClosing",
    initial: "false",
    states: {
      true: { messages: { TO_FALSE: "false" } },
      false: { messages: { TO_TRUE: "true" } },
    },
  },
  {
    name: "openness",
    initial: "closed",
    states: {
      closed: {
        messages: {
          READY_TO_OPEN: [
            {
              guard: GUARD_NAMES.NOT_SKIP_OPENING_MSG,
              target: "opening",
            },
            {
              target: "open",
            },
          ],
        },
        machines: [
          {
            name: "status",
            initial: "safe-to-unmount",
            states: {
              "safe-to-unmount": {},
              pending: {
                messages: {
                  OPEN: [
                    {
                      guard: GUARD_NAMES.SKIP_OPENING,
                      target: "flushing-to-preparing-open",
                    },
                    { target: "flushing-to-preparing-opening" },
                  ],
                  "": "safe-to-unmount",
                },
              },
              "flushing-to-preparing-open": {
                messages: { "": "preparing-open" },
              },
              "flushing-to-preparing-opening": {
                messages: { "": "preparing-opening" },
              },
              "preparing-open": {},
              "preparing-opening": {},
            },
          },
        ],
      },
      opening: {
        messages: { NEXT: "open" },
      },
      open: {
        messages: {
          ACTUALLY_CLOSE: [
            {
              guard: GUARD_NAMES.SKIP_CLOSING,
              target: "openness:closed.status:pending",
            },
          ],
          SWIPED_OUT: "openness:closed.status:pending",
          READY_TO_CLOSE: [
            {
              guard: GUARD_NAMES.NOT_SKIP_CLOSING_MSG,
              target: "closing",
            },
          ],
          STEP: "open",
        },
        machines: [
          {
            name: "scroll",
            initial: "ended",
            states: {
              ended: {
                messages: { SCROLL_START: "ongoing" },
                machines: [
                  {
                    name: "afterPaintEffectsRun",
                    initial: "false",
                    states: {
                      false: { messages: { OCCURRED: "true" } },
                      true: {},
                    },
                  },
                ],
              },
              ongoing: { messages: { SCROLL_END: "ended" } },
            },
          },
          {
            name: "move",
            initial: "ended",
            states: {
              ended: { messages: { MOVE_START: "ongoing" } },
              ongoing: { messages: { MOVE_END: "ended" } },
            },
          },
          {
            name: "swipe",
            silentOnly: true,
            initial: "unstarted",
            states: {
              unstarted: { messages: { SWIPE_START: "ongoing" } },
              ongoing: { messages: { SWIPE_END: "ended" } },
              ended: {
                messages: { SWIPE_START: "ongoing", SWIPE_RESET: "unstarted" },
              },
            },
          },
          {
            name: "evaluateCloseMessage",
            silentOnly: true,
            initial: "false",
            states: {
              false: { messages: { CLOSE: "true" } },
              true: { messages: { CLOSE: "false" } },
            },
          },
          {
            name: "evaluateStepMessage",
            silentOnly: true,
            initial: "false",
            states: {
              false: { messages: { STEP: "true" } },
              true: { messages: { STEP: "false" } },
            },
          },
        ],
      },
      closing: { messages: { NEXT: "openness:closed.status:pending" } },
    },
  },
  {
    name: "scrollContainerTouch",
    silentOnly: true,
    initial: "ended",
    states: {
      ended: { messages: { TOUCH_START: "ongoing" } },
      ongoing: { messages: { TOUCH_END: "ended" } },
    },
  },
  {
    name: "backStuck",
    silentOnly: true,
    initial: "false",
    states: {
      false: { messages: { STUCK_START: "true" } },
      true: { messages: { STUCK_END: "false" } },
    },
  },
  {
    name: "frontStuck",
    silentOnly: true,
    initial: "false",
    states: {
      false: { messages: { STUCK_START: "true" } },
      true: { messages: { STUCK_END: "false" } },
    },
  },
  {
    name: "elementsReady",
    initial: "false",
    states: {
      false: { messages: { ELEMENTS_REGISTERED: "true" } },
      true: { messages: { RESET: "false" } },
    },
  },
];

/**
 * Position machines array for StateMachineGroup.
 * Matches Silk's second tw() call structure.
 */
export const POSITION_MACHINES = [
  {
    name: "active",
    initial: "false",
    states: {
      false: { messages: { TO_TRUE: "true" } },
      true: { messages: { TO_FALSE: "false" } },
    },
  },
  {
    name: "position",
    initial: "out",
    states: {
      out: {
        messages: {
          READY_TO_GO_FRONT: [
            {
              guard: GUARD_NAMES.SKIP_OPENING,
              target: "position:front.status:idle",
            },
            {
              target: "position:front.status:opening",
            },
          ],
        },
      },
      front: {
        machines: [
          {
            name: "status",
            initial: "opening",
            states: {
              opening: {
                messages: {
                  NEXT: "idle",
                },
              },
              closing: {
                messages: {
                  NEXT: "position:out",
                },
              },
              idle: {
                messages: {
                  READY_TO_GO_DOWN: [
                    {
                      guard: GUARD_NAMES.SKIP_OPENING,
                      target: "position:covered.status:idle",
                    },
                    {
                      target: "position:covered.status:going-down",
                    },
                  ],
                  READY_TO_GO_OUT: "closing",
                  GO_OUT: "position:out",
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
                messages: {
                  NEXT: "idle",
                },
              },
              "going-up": {
                messages: {
                  NEXT: "indeterminate",
                },
              },
              indeterminate: {
                messages: {
                  GOTO_idle: "idle",
                  GOTO_front: "position:front.status:idle",
                },
              },
              idle: {
                messages: {
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
                  GOTO_front: "position:front.status:idle",
                },
              },
              "come-back": {
                messages: {
                  "": "idle",
                },
              },
            },
          },
        ],
      },
    },
  },
];
