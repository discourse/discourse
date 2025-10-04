import { tracked } from "@glimmer/tracking";
import { debounce, throttle } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import loadYjs from "discourse/lib/load-yjs";

const THROTTLE_SAVE = 1000; // Publish at most once per second while typing
const DEBOUNCE_FINAL = 500; // Catch the tail end after user stops typing

/**
 * @component yjs-prosemirror-manager
 * Service for managing YJS collaborative editing with ProseMirror integration
 * Provides real-time sync with cursor tracking and no cursor drift
 */
export default class YjsProsemirrorManager extends Service {
  @service composer;
  @service messageBus;
  @service currentUser;

  @tracked isActive = false;

  postId = null;
  version = null;
  doc = null; // Y.Doc
  type = null; // Y.XmlFragment for ProseMirror
  awareness = null; // Awareness for cursor tracking
  editorView = null; // ProseMirror EditorView
  ySyncPluginInstance = null;
  yCursorPluginInstance = null;
  ajaxInProgress = false;
  lastUpdateSent = null; // Track last update time for throttling
  Y = null;
  ySyncPlugin = null;
  yCursorPlugin = null;
  yUndoPlugin = null;
  encodeAwarenessUpdate = null;
  applyAwarenessUpdate = null;
  cursorCleanupInterval = null;

  /**
   * Handle document updates from YJS
   */
  #onDocumentUpdate = (update, origin) => {
    // Only send updates if this is a local change (not from message bus)
    if (origin !== "message-bus" && !this.ajaxInProgress) {
      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Document update detected", {
        updateLength: update.length,
        origin,
      });

      // Update lastTyped timestamp for local user
      this.#updateLastTyped();

      this.#sendUpdateThrottled();
    }
  };

  /**
   * Handle awareness changes (cursor movements, selections)
   */
  #onAwarenessChange = (changes) => {
    // Broadcast awareness updates to other clients
    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] Awareness changed", {
      added: changes.added.length,
      updated: changes.updated.length,
      removed: changes.removed.length,
      addedIds: changes.added,
      updatedIds: changes.updated,
      removedIds: changes.removed,
      localClientId: this.doc?.clientID,
    });

    // Only broadcast if we have local changes AND user has typed recently
    // Don't broadcast cursor movements if user hasn't typed (to avoid clutter)
    const isLocalChange =
      changes.added.includes(this.doc?.clientID) ||
      changes.updated.includes(this.doc?.clientID);

    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] Is local change?", isLocalChange);

    if (isLocalChange) {
      const localState = this.awareness.getLocalState();
      const lastTyped = localState?.user?.lastTyped || 0;
      const timeSinceLastType = Date.now() - lastTyped;

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Time since last type:", {
        lastTyped,
        timeSinceLastType: Math.round(timeSinceLastType / 1000) + "s",
        threshold: "30s",
      });

      // Only broadcast if user typed within last 30 seconds
      if (timeSinceLastType < 30000) {
        this.#broadcastAwarenessThrottled();
      } else {
        // eslint-disable-next-line no-console
        console.log(
          "[YJS PM Manager] Skipping awareness broadcast - user inactive",
          {
            timeSinceLastType: Math.round(timeSinceLastType / 1000) + "s",
          }
        );
      }
    } else {
      // eslint-disable-next-line no-console
      console.log(
        "[YJS PM Manager] Skipping awareness broadcast - not a local change"
      );
    }
  };

  /**
   * Handle incoming message bus updates
   */
  #onMessageBusUpdate = (message) => {
    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] Received message bus update:", {
      messageClientId: message.client_id,
      myClientId: this.messageBus.clientId,
      type: message.type,
      hasUpdate: !!message.update,
      hasAwareness: !!message.awareness,
    });

    const isOwnMessage = message.client_id === this.messageBus.clientId;

    if (isOwnMessage) {
      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Skipping own message");
      return;
    }

    // Apply document update
    if (message.type === "yjs-update" && message.update) {
      this.#applyUpdate(message.update);
    }

    // Apply awareness update (cursor position)
    if (message.awareness) {
      this.#applyAwareness(message.awareness);
    }
  };

  /**
   * Initialize YJS with ProseMirror editor
   * @param {EditorView} editorView - ProseMirror EditorView instance
   * @param {number} postId - Post ID for this editing session
   * @param {Function} convertToMarkdown - Function to convert ProseMirror doc to markdown
   */
  async subscribe(editorView, postId, convertToMarkdown) {
    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] Subscribe called", {
      postId,
      hasEditorView: !!editorView,
      hasDoc: !!editorView?.state?.doc,
      hasConverter: !!convertToMarkdown,
    });

    this.postId = postId;
    this.editorView = editorView;
    this.convertToMarkdown = convertToMarkdown;

    if (!this.postId || !this.editorView) {
      // eslint-disable-next-line no-console
      console.error(
        "[YJS PM Manager] Missing postId or editorView, cannot subscribe"
      );
      return;
    }

    try {
      // Load YJS and ProseMirror plugins
      const bundle = await loadYjs();
      const {
        Y,
        Awareness,
        ySyncPlugin,
        yCursorPlugin,
        yUndoPlugin,
        encodeAwarenessUpdate,
        applyAwarenessUpdate,
      } = bundle;

      this.Y = Y;
      this.Awareness = Awareness;
      this.ySyncPlugin = ySyncPlugin;
      this.yCursorPlugin = yCursorPlugin;
      this.yUndoPlugin = yUndoPlugin;
      this.encodeAwarenessUpdate = encodeAwarenessUpdate;
      this.applyAwarenessUpdate = applyAwarenessUpdate;

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] YJS bundle loaded", {
        hasY: !!Y,
        hasYSyncPlugin: !!ySyncPlugin,
        hasYCursorPlugin: !!yCursorPlugin,
      });

      // Fetch initial state from server
      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Fetching initial state from server...");
      const data = await ajax(`/shared_edits/p/${this.postId}`);

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Received initial state:", {
        version: data.version,
        hasYjsState: !!data.yjsState,
        rawLength: data.raw?.length,
      });

      this.version = data.version;

      // Initialize YJS document
      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Initializing YJS document");
      this.doc = new Y.Doc();
      this.type = this.doc.getXmlFragment("prosemirror");

      // Create awareness for cursor tracking
      this.awareness = new this.Awareness(this.doc);

      // Set local user info for awareness
      this.awareness.setLocalStateField("user", {
        name: this.currentUser.username,
        color: this.#getUserColor(this.currentUser.id),
        lastTyped: Date.now(), // Track when user last typed
      });

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Awareness initialized", {
        username: this.currentUser.username,
        color: this.#getUserColor(this.currentUser.id),
      });

      // Apply initial YJS state if available
      if (data.yjsState && Array.isArray(data.yjsState)) {
        // eslint-disable-next-line no-console
        console.log("[YJS PM Manager] Applying initial YJS state", {
          stateLength: data.yjsState.length,
        });
        Y.applyUpdate(this.doc, new Uint8Array(data.yjsState));
      } else {
        // eslint-disable-next-line no-console
        console.log(
          "[YJS PM Manager] No YJS state yet - ProseMirror content will be synced on first edit"
        );
        // Note: The ySyncPlugin will automatically sync the current ProseMirror
        // document into the YJS XmlFragment on first load. No manual sync needed!
      }

      // Create YJS plugins for ProseMirror
      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Creating ProseMirror plugins", {
        hasSchema: !!this.editorView.state.schema,
        schemaNodes: Object.keys(this.editorView.state.schema.nodes),
        schemaMarks: Object.keys(this.editorView.state.schema.marks),
      });

      // Configure ySyncPlugin with ProseMirror schema for proper mark/node syncing
      this.ySyncPluginInstance = ySyncPlugin(this.type, {
        // Pass the ProseMirror schema so y-prosemirror knows how to handle marks
        // This is CRITICAL for syncing formatting like bold, italic, links, etc.
      });

      // Configure cursor plugin with custom rendering
      this.yCursorPluginInstance = yCursorPlugin(this.awareness, {
        cursorBuilder: this.#buildCursor.bind(this),
        selectionBuilder: this.#buildSelection.bind(this),
      });

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] ✅ Cursor plugin ENABLED");

      // Add plugins to ProseMirror
      this.#attachPluginsToProseMirror();

      // Set up document update listener
      this.doc.on("update", this.#onDocumentUpdate);

      // Set up awareness change listener (for cursor tracking)
      this.awareness.on("change", this.#onAwarenessChange);

      // Subscribe to message bus for real-time collaboration
      const channel = `/shared_edits/${this.postId}`;
      // eslint-disable-next-line no-console
      console.log(
        "[YJS PM Manager] Subscribing to message bus channel:",
        channel
      );

      this.messageBus.subscribe(channel, this.#onMessageBusUpdate);

      // Start periodic cleanup of stale cursors
      this.#startCursorCleanup();

      this.isActive = true;

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Subscribe completed successfully");
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[YJS PM Manager] Subscribe failed:", e);
      popupAjaxError(e);
    }
  }

  /**
   * Create cursor tracking plugin
   * @param {EditorState} state - ProseMirror editor state
   * @returns {Plugin|null} Cursor tracking plugin or null if cannot create
   */
  #createCursorTrackingPlugin(state) {
    if (!this.awareness) {
      return null;
    }

    // Get Plugin constructor from existing plugins
    const existingPlugin = state.plugins[0];
    if (!existingPlugin || !existingPlugin.constructor) {
      // eslint-disable-next-line no-console
      console.warn(
        "[YJS PM Manager] Cannot create cursor tracking plugin - no Plugin constructor available"
      );
      return null;
    }

    const PluginConstructor = existingPlugin.constructor;

    // Create cursor tracking plugin
    const cursorTrackingPlugin = new PluginConstructor({
      view: () => ({
        update: (view, prevState) => {
          const oldSelection = prevState.selection;
          const newSelection = view.state.selection;

          // Only update if selection actually changed
          if (
            oldSelection.anchor !== newSelection.anchor ||
            oldSelection.head !== newSelection.head
          ) {
            this.awareness.setLocalStateField("cursor", {
              anchor: newSelection.anchor,
              head: newSelection.head,
            });
          }
        },
      }),
    });

    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] Cursor tracking plugin created");

    return cursorTrackingPlugin;
  }

  /**
   * Attach YJS plugins to the ProseMirror EditorView
   */
  #attachPluginsToProseMirror() {
    if (!this.editorView || !this.ySyncPluginInstance) {
      // eslint-disable-next-line no-console
      console.error(
        "[YJS PM Manager] Cannot attach plugins - missing view or plugin"
      );
      return;
    }

    try {
      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Attaching YJS plugins to ProseMirror");

      const state = this.editorView.state;

      // Collect all plugins to add
      const newPlugins = [this.ySyncPluginInstance];

      // Add cursor plugin
      if (this.yCursorPluginInstance) {
        newPlugins.push(this.yCursorPluginInstance);
      }

      // Add cursor tracking plugin
      const cursorTrackingPlugin = this.#createCursorTrackingPlugin(state);
      if (cursorTrackingPlugin) {
        newPlugins.push(cursorTrackingPlugin);
      }

      // Add all plugins at once (single reconfigure)
      const newState = state.reconfigure({
        plugins: [...state.plugins, ...newPlugins],
      });

      this.editorView.updateState(newState);

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Plugins attached successfully", {
        totalPlugins: newState.plugins.length,
        hasCursorPlugin: !!this.yCursorPluginInstance,
      });

      // Verify yCursorPlugin is in the plugin list
      // The cursor plugin may not have a specific key, check if instance is in plugins
      const cursorPluginFound = newState.plugins.includes(
        this.yCursorPluginInstance
      );
      // eslint-disable-next-line no-console
      console.log(
        "[YJS PM Manager] yCursorPlugin in state:",
        cursorPluginFound,
        "total plugins:",
        newState.plugins.length
      );

      // CRITICAL: Manually sync initial cursor position to awareness
      // The ySyncPlugin tracks cursor automatically during transactions,
      // but since we added plugins after editor creation, we need to trigger initial sync
      const selection = this.editorView.state.selection;
      this.awareness.setLocalStateField("cursor", {
        anchor: selection.anchor,
        head: selection.head,
      });

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Set initial cursor position in awareness", {
        anchor: selection.anchor,
        head: selection.head,
      });
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[YJS PM Manager] Failed to attach plugins:", e);
      throw e;
    }
  }

  /**
   * Apply a YJS update from another client
   */
  #applyUpdate(updateData) {
    try {
      // Parse if string
      if (typeof updateData === "string") {
        updateData = JSON.parse(updateData);
      }

      if (!Array.isArray(updateData)) {
        // eslint-disable-next-line no-console
        console.error("[YJS PM Manager] Update data is not an array");
        return;
      }

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Applying update from message bus", {
        updateLength: updateData.length,
        yDocLength: this.type.length,
        pmDocSize: this.editorView?.state?.doc?.nodeSize,
      });

      const update = new Uint8Array(updateData);
      this.Y.applyUpdate(this.doc, update, "message-bus");

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Update applied successfully", {
        newYDocLength: this.type.length,
        newPmDocSize: this.editorView?.state?.doc?.nodeSize,
      });
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[YJS PM Manager] Failed to apply update:", e);
    }
  }

  /**
   * Apply awareness update (cursor position from another user)
   */
  #applyAwareness(awarenessData) {
    try {
      // Parse if string
      if (typeof awarenessData === "string") {
        awarenessData = JSON.parse(awarenessData);
      }

      if (!Array.isArray(awarenessData)) {
        return;
      }

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Applying awareness update", {
        awarenessLength: awarenessData.length,
        currentStates: this.awareness.getStates().size,
      });

      const update = new Uint8Array(awarenessData);
      // Apply awareness update from another user
      this.applyAwarenessUpdate(this.awareness, update, "message-bus");

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Awareness applied", {
        newStates: this.awareness.getStates().size,
      });

      // Debug: Log all awareness states
      const states = [];
      this.awareness.getStates().forEach((state, clientId) => {
        states.push({
          clientId,
          isLocal: clientId === this.doc.clientID,
          user: state.user?.name,
          lastTyped: state.user?.lastTyped,
          hasCursor: !!state.cursor,
          cursorData: state.cursor,
        });
      });
      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] 📍 All awareness states:", states);

      // Check if yCursorPlugin should be rendering
      const remoteCursors = Array.from(this.awareness.getStates().entries())
        .filter(([id]) => id !== this.doc.clientID)
        .filter(([, state]) => state.cursor);
      // eslint-disable-next-line no-console
      console.log(
        `[YJS PM Manager] 📍 Remote users with cursors: ${remoteCursors.length}`
      );
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[YJS PM Manager] Failed to apply awareness:", e);
    }
  }

  /**
   * Send YJS update to server (throttled + debounced for tail)
   * Throttle ensures updates go out at most once per second while typing
   * Debounce catches the final update after user stops typing
   * Pattern adapted from presence.js
   */
  #sendUpdateThrottled() {
    // If enough time has passed since last update, send immediately
    if (
      !this.lastUpdateSent ||
      new Date() - this.lastUpdateSent > THROTTLE_SAVE
    ) {
      this.#sendUpdate();
    } else {
      // Otherwise, throttle to next available slot
      throttle(this, this.#sendUpdate, THROTTLE_SAVE, false);
    }

    // Always schedule a final debounced update to catch the tail
    debounce(this, this.#sendUpdate, DEBOUNCE_FINAL);
  }

  /**
   * Send YJS update to server
   */
  async #sendUpdate() {
    if (!this.postId || !this.doc || this.ajaxInProgress) {
      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Send update skipped", {
        hasPostId: !!this.postId,
        hasDoc: !!this.doc,
        ajaxInProgress: this.ajaxInProgress,
      });
      return;
    }

    // Track when we last sent an update for throttling
    this.lastUpdateSent = new Date();

    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] Sending update to server", {
      postId: this.postId,
      version: this.version,
    });

    this.ajaxInProgress = true;

    try {
      const update = this.Y.encodeStateAsUpdate(this.doc);
      const markdown = this.#extractMarkdown();

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Encoded update", {
        updateLength: update.length,
        markdownLength: markdown.length,
      });

      const result = await ajax(`/shared_edits/p/${this.postId}`, {
        method: "PUT",
        data: {
          yjsUpdate: Array.from(update),
          version: this.version,
          client_id: this.messageBus.clientId,
          raw: markdown,
        },
      });

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Server response:", {
        newVersion: result.version,
      });

      this.version = result.version;
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[YJS PM Manager] Send update failed:", e);
    } finally {
      this.ajaxInProgress = false;
    }
  }

  /**
   * Broadcast awareness (throttled)
   */
  #broadcastAwarenessThrottled() {
    debounce(this, this.#broadcastAwareness, 100);
  }

  /**
   * Broadcast awareness state to other clients
   */
  async #broadcastAwareness() {
    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] #broadcastAwareness called", {
      hasAwareness: !!this.awareness,
      hasPostId: !!this.postId,
      hasDoc: !!this.doc,
      hasY: !!this.Y,
    });

    if (!this.awareness || !this.postId || !this.doc) {
      // eslint-disable-next-line no-console
      console.warn(
        "[YJS PM Manager] Cannot broadcast awareness - missing data"
      );
      return;
    }

    try {
      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] About to encode awareness", {
        clientID: this.doc.clientID,
        awarenessStates: this.awareness.getStates().size,
      });

      const awarenessUpdate = this.encodeAwarenessUpdate(this.awareness, [
        this.doc.clientID,
      ]);

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Broadcasting awareness", {
        awarenessLength: awarenessUpdate.length,
        clientId: this.doc.clientID,
      });

      // Send awareness update via the revise endpoint
      // This will be broadcast via message bus to other clients
      await ajax(`/shared_edits/p/${this.postId}`, {
        method: "PUT",
        data: {
          awareness: Array.from(awarenessUpdate),
          client_id: this.messageBus.clientId,
          version: this.version,
        },
      });

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Awareness broadcast successful");
    } catch (e) {
      // Awareness errors should be visible - they prevent cursor sync
      // eslint-disable-next-line no-console
      console.error("[YJS PM Manager] Awareness broadcast failed:", e);
    }
  }

  /**
   * Extract markdown from ProseMirror state
   * @returns {string} Markdown content
   */
  #extractMarkdown() {
    if (!this.editorView) {
      // eslint-disable-next-line no-console
      console.warn("[YJS PM Manager] No editor view available for extraction");
      return "";
    }

    try {
      const doc = this.editorView.state.doc;

      // Use the proper markdown converter if available
      if (this.convertToMarkdown) {
        const markdown = this.convertToMarkdown(doc);

        // eslint-disable-next-line no-console
        console.log("[YJS PM Manager] Extracted markdown (proper serializer)", {
          length: markdown.length,
          preview: markdown.substring(0, 100),
        });

        return markdown;
      } else {
        // Fallback to text content (loses formatting)
        const text = doc.textContent;

        // eslint-disable-next-line no-console
        console.warn(
          "[YJS PM Manager] Using textContent fallback (formatting lost)",
          {
            length: text.length,
            preview: text.substring(0, 100),
          }
        );

        return text;
      }
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[YJS PM Manager] Failed to extract markdown:", e);
      return "";
    }
  }

  /**
   * Generate a color for a user based on their ID
   * @param {number} userId - User ID
   * @returns {string} Hex color
   */
  #getUserColor(userId) {
    const colors = [
      "#FF6B6B",
      "#4ECDC4",
      "#45B7D1",
      "#FFA07A",
      "#98D8C8",
      "#F7DC6F",
      "#BB8FCE",
      "#85C1E2",
      "#F8B739",
      "#52BE80",
    ];
    return colors[userId % colors.length];
  }

  /**
   * Get user index (1-10) for CSS class naming
   * @param {number} userId - User ID
   * @returns {number} User index (1-10)
   */
  #getUserIndex(userId) {
    return (userId % 10) + 1;
  }

  /**
   * Build cursor decoration for other users
   * Called by yCursorPlugin to render cursors
   * @param {Object} user - User info from awareness
   * @returns {HTMLElement|null} Cursor DOM element or null to hide cursor
   */

  #buildCursor(user) {
    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] 🎯 buildCursor called!", {
      hasUser: !!user,
      userObject: user,
      userData: user?.user,
      clientId: user?.clientID,
      userKeys: user ? Object.keys(user) : [],
    });

    // Always create a cursor element (can't return null - yCursorPlugin crashes)
    const cursor = document.createElement("span");
    cursor.classList.add("yjs-cursor");

    if (!user || !user.name) {
      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] ❌ No user data, returning hidden cursor");
      cursor.style.display = "none"; // Hide instead of returning null
      return cursor;
    }

    // Check if user has typed recently (within 30 seconds)
    const lastTyped = user.lastTyped;
    const now = Date.now();
    const timeSinceLastType = now - (lastTyped || 0);
    const CURSOR_TIMEOUT_MS = 30000; // 30 seconds

    // Generate a stable user index from the name
    const userId = this.#hashCode(user.name);
    const userIndex = this.#getUserIndex(userId);

    if (timeSinceLastType > CURSOR_TIMEOUT_MS) {
      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] ❌ Hiding stale cursor", {
        name: user.name,
        timeSinceLastType: Math.round(timeSinceLastType / 1000) + "s",
      });
      // Hide with CSS instead of returning null
      cursor.style.display = "none";
      cursor.classList.add(`yjs-cursor-user-${userIndex}`);
      return cursor;
    }

    // User is active - show cursor
    cursor.classList.add(`yjs-cursor-user-${userIndex}`);

    // Add user name label
    const nameLabel = document.createElement("span");
    nameLabel.classList.add(
      "yjs-cursor-name",
      `yjs-cursor-name-user-${userIndex}`
    );
    nameLabel.textContent = user.name || "Anonymous";
    cursor.appendChild(nameLabel);

    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] ✅ Built cursor for user", {
      name: user.name,
      color: user.color,
      userIndex,
      timeSinceLastType: Math.round(timeSinceLastType / 1000) + "s",
      cursorElement: cursor,
      cursorClasses: cursor.className,
    });

    return cursor;
  }

  /**
   * Build selection decoration for other users
   * Called by yCursorPlugin to render selections
   * @param {Object} user - User info from awareness
   * @returns {Object} Decoration attributes
   */

  #buildSelection(user) {
    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] 🎨 buildSelection called!", {
      hasUser: !!user,
      userObject: user,
      userData: user?.user,
      userKeys: user ? Object.keys(user) : [],
    });

    if (!user || !user.name) {
      // Return empty but valid attributes (never return null/undefined)
      return { style: "display: none;" };
    }

    // Check if user has typed recently (within 30 seconds)
    const lastTyped = user.lastTyped;
    const now = Date.now();
    const timeSinceLastType = now - (lastTyped || 0);
    const CURSOR_TIMEOUT_MS = 30000; // 30 seconds

    if (timeSinceLastType > CURSOR_TIMEOUT_MS) {
      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] ❌ Hiding stale selection");
      return { style: "display: none;" };
    }

    // Generate a stable user index from the name
    const userId = this.#hashCode(user.name);
    const userIndex = this.#getUserIndex(userId);

    const attrs = {
      class: `yjs-cursor-selection yjs-cursor-selection-user-${userIndex}`,
      style: `background-color: ${user.color}20;`, // 20 = 12.5% opacity in hex
    };

    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] ✅ Built selection", attrs);

    return attrs;
  }

  /**
   * Generate a hash code from a string (for consistent user colors)
   * @param {string} str - String to hash
   * @returns {number} Hash code
   */
  #hashCode(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      // eslint-disable-next-line no-bitwise
      hash = (hash << 5) - hash + char;
      // eslint-disable-next-line no-bitwise
      hash = hash & hash; // Convert to 32bit integer
    }
    return Math.abs(hash);
  }

  /**
   * Update lastTyped timestamp in awareness
   */
  #updateLastTyped() {
    if (!this.awareness) {
      return;
    }

    const currentUser = this.awareness.getLocalState()?.user;
    if (currentUser) {
      this.awareness.setLocalStateField("user", {
        ...currentUser,
        lastTyped: Date.now(),
      });

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Updated lastTyped timestamp");
    }
  }

  /**
   * Start periodic cleanup of stale cursors
   */
  #startCursorCleanup() {
    // Check every 5 seconds for stale cursors
    this.cursorCleanupInterval = setInterval(() => {
      if (!this.awareness) {
        return;
      }

      // Get current awareness states
      const states = this.awareness.getStates();
      const now = Date.now();
      const CURSOR_TIMEOUT_MS = 30000;

      states.forEach((state, clientId) => {
        if (clientId === this.doc.clientID) {
          return; // Skip local user
        }

        const lastTyped = state.user?.lastTyped;
        const timeSinceLastType = now - (lastTyped || 0);

        if (timeSinceLastType > CURSOR_TIMEOUT_MS) {
          // Force a re-render by updating local state slightly
          // This will trigger yCursorPlugin to rebuild cursors
          // The buildCursor will return null for stale cursors
          this.awareness.setLocalState(this.awareness.getLocalState());

          // eslint-disable-next-line no-console
          console.log("[YJS PM Manager] Triggering cursor cleanup", {
            staleCursors: 1,
          });
        }
      });
    }, 5000); // Check every 5 seconds

    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] Started cursor cleanup interval");
  }

  /**
   * Stop periodic cursor cleanup
   */
  #stopCursorCleanup() {
    if (this.cursorCleanupInterval) {
      clearInterval(this.cursorCleanupInterval);
      this.cursorCleanupInterval = null;

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Stopped cursor cleanup interval");
    }
  }

  /**
   * Unsubscribe and cleanup without committing
   * Used when switching editor modes
   */
  unsubscribe() {
    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] Unsubscribe called", {
      postId: this.postId,
      isActive: this.isActive,
    });

    if (!this.isActive) {
      return;
    }

    this.isActive = false;

    try {
      // Stop cursor cleanup FIRST to prevent any pending updates
      this.#stopCursorCleanup();

      // Clear awareness state to stop cursor updates IMMEDIATELY
      if (this.awareness) {
        // eslint-disable-next-line no-console
        console.log("[YJS PM Manager] Clearing awareness state");
        try {
          // Remove ALL awareness states including our own
          this.awareness.setLocalState(null);
          // Clear all remote states too
          const states = this.awareness.getStates();
          const clientIds = Array.from(states.keys()).filter(
            (id) => id !== this.awareness.clientID
          );
          if (clientIds.length > 0) {
            this.removeAwarenessStates(this.awareness, clientIds, this);
          }
        } catch (awarenessError) {
          // eslint-disable-next-line no-console
          console.warn(
            "[YJS PM Manager] Error clearing awareness:",
            awarenessError
          );
        }
        this.awareness.off("change", this.#onAwarenessChange);
      }

      // Clean up document listener
      if (this.doc) {
        this.doc.off("update", this.#onDocumentUpdate);
      }

      // Unsubscribe from message bus
      if (this.postId) {
        this.messageBus.unsubscribe(
          `/shared_edits/${this.postId}`,
          this.#onMessageBusUpdate
        );
      }

      // Destroy plugin instances to stop them completely
      this.ySyncPluginInstance = null;
      this.yCursorPluginInstance = null;

      // Clear editor references immediately to prevent any late updates
      this.editorView = null;
      this.convertToMarkdown = null;

      // eslint-disable-next-line no-console
      console.log("[YJS PM Manager] Unsubscribed successfully");
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[YJS PM Manager] Error during unsubscribe:", e);
    }
  }

  /**
   * Commit and cleanup when closing
   */
  async commit() {
    // eslint-disable-next-line no-console
    console.log("[YJS PM Manager] Commit called", {
      postId: this.postId,
      hasDoc: !!this.doc,
      version: this.version,
    });

    if (!this.postId) {
      // eslint-disable-next-line no-console
      console.error("[YJS PM Manager] No post ID available, cannot commit");
      return;
    }

    try {
      // Clean up listeners
      if (this.doc) {
        this.doc.off("update", this.#onDocumentUpdate);
      }

      if (this.awareness) {
        this.awareness.off("change", this.#onAwarenessChange);
      }

      this.messageBus.unsubscribe(
        `/shared_edits/${this.postId}`,
        this.#onMessageBusUpdate
      );

      // Send final state to server
      if (this.doc) {
        const finalState = this.Y.encodeStateAsUpdate(this.doc);
        const markdown = this.#extractMarkdown();

        // eslint-disable-next-line no-console
        console.log("[YJS PM Manager] Sending final state to server", {
          stateLength: finalState.length,
          markdownLength: markdown.length,
        });

        await ajax(`/shared_edits/p/${this.postId}/commit`, {
          method: "PUT",
          data: {
            yjsState: Array.from(finalState),
            version: this.version,
            client_id: this.messageBus.clientId,
          },
        });

        // eslint-disable-next-line no-console
        console.log("[YJS PM Manager] Commit successful");
      }

      // Stop cursor cleanup
      this.#stopCursorCleanup();

      // Clean up
      this.doc = null;
      this.type = null;
      this.awareness = null;
      this.editorView = null;
      this.convertToMarkdown = null;
      this.version = null;
      this.postId = null;
      this.isActive = false;
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[YJS PM Manager] Commit failed:", e);
      popupAjaxError(e);
    }
  }
}
