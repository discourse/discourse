import { debounce, throttle } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import loadYjs from "discourse/lib/load-yjs";

const THROTTLE_SAVE = 1000; // Publish at most once per second while typing
const DEBOUNCE_FINAL = 500; // Catch the tail end after user stops typing

/**
 * @component yjs-shared-edit-manager
 * @param {Object} composer - The composer service
 * @param {Object} messageBus - The message bus service
 */
export default class YjsSharedEditManager extends Service {
  @service composer;
  @service messageBus;

  ajaxInProgress = false;
  doc = null;
  text = null;
  version = null;
  Y = null;
  postId = null; // Store post ID to use even after composer is closed
  lastUpdateSent = null; // Track last update time for throttling

  #onTextChange = (event, transaction) => {
    // Only send updates if we're not applying a remote change
    // eslint-disable-next-line no-console
    console.log("[YJS Manager] Text change detected", {
      ajaxInProgress: this.ajaxInProgress,
      isLocal: transaction.local,
      origin: transaction.origin,
      textContent: this.text?.toString().substring(0, 50) + "...",
    });
    if (!this.ajaxInProgress && transaction.local) {
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Scheduling update send (throttled)");
      this.#sendUpdateThrottled();
    }
  };

  #onDocumentUpdate = (update, origin, doc, transaction) => {
    // Send updates to server via message bus
    // eslint-disable-next-line no-console
    console.log("[YJS Manager] Document update detected", {
      updateLength: update.length,
      origin,
      isLocal: transaction.local,
      ajaxInProgress: this.ajaxInProgress,
    });

    // Only send if it's a local change and we're not already sending
    if (transaction.local && !this.ajaxInProgress) {
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Scheduling document update send");
      this.#sendUpdateThrottled();
    }
  };

  #onComposerReplyChange = () => {
    if (!this.text || this.ajaxInProgress) {
      return;
    }

    const composerContent = this.composer.model.get("reply") || "";
    const yjsContent = this.text.toString();

    // eslint-disable-next-line no-console
    console.log("[YJS Manager] Composer reply changed", {
      composerLength: composerContent.length,
      yjsLength: yjsContent.length,
      isDifferent: composerContent !== yjsContent,
      composerPreview: composerContent.substring(0, 50) + "...",
      yjsPreview: yjsContent.substring(0, 50) + "...",
    });

    // Only sync if content is actually different
    if (composerContent !== yjsContent) {
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Syncing composer changes to YJS document");

      // Update YJS document to match composer
      this.doc.transact(() => {
        this.text.delete(0, yjsContent.length);
        this.text.insert(0, composerContent);
      });
    }
  };

  async #loadYjs() {
    if (this.Y) {
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] YJS already loaded");
      return this.Y;
    }

    // eslint-disable-next-line no-console
    console.log("[YJS Manager] Loading YJS from core bundle");

    try {
      // Load YJS from Discourse core bundle
      const bundle = await loadYjs();
      const { Y, ySyncPlugin, yCursorPlugin, yUndoPlugin } = bundle;
      this.Y = Y;

      if (!this.Y) {
        throw new Error("YJS library loaded but Y is not defined");
      }

      // eslint-disable-next-line no-console
      console.log("[YJS Manager] YJS loaded successfully", {
        hasY: !!this.Y,
        hasDoc: !!this.Y.Doc,
        hasText: !!this.Y.Text,
        hasApplyUpdate: !!this.Y.applyUpdate,
        hasEncodeStateAsUpdate: !!this.Y.encodeStateAsUpdate,
        hasYSyncPlugin: !!ySyncPlugin,
        hasYCursorPlugin: !!yCursorPlugin,
        hasYUndoPlugin: !!yUndoPlugin,
      });

      return this.Y;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("[YJS Manager] Failed to load YJS:", error);
      throw error;
    }
  }

  async subscribe() {
    // Store post ID early before composer might close
    this.postId = this.#postId;

    // eslint-disable-next-line no-console
    console.log("[YJS Manager] Subscribe called", {
      postId: this.postId,
      composerModel: !!this.composer.model,
    });

    if (!this.postId) {
      // eslint-disable-next-line no-console
      console.error("[YJS Manager] No post ID available, cannot subscribe");
      return;
    }

    try {
      // Load Yjs library
      const Y = await this.#loadYjs();

      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Fetching initial state from server...");
      const data = await ajax(`/shared_edits/p/${this.postId}`);
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Received initial state:", {
        version: data.version,
        hasYjsState: !!data.yjsState,
        raw: data.raw?.substring(0, 50) + "...",
      });

      if (!this.composer.model || this.isDestroying || this.isDestroyed) {
        // eslint-disable-next-line no-console
        console.warn(
          "[YJS Manager] Subscribe aborted - composer model destroyed"
        );
        return;
      }

      this.version = data.version;

      // Initialize Yjs document
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Initializing YJS document");
      this.doc = new Y.Doc();
      this.text = this.doc.getText("content");

      // Load initial state if available
      if (data.yjsState) {
        // Check if yjsState is in the old JSON format or new binary format
        const isOldFormat =
          typeof data.yjsState === "object" &&
          data.yjsState.content !== undefined;

        // eslint-disable-next-line no-console
        console.log("[YJS Manager] Inspecting yjsState", {
          type: typeof data.yjsState,
          isArray: Array.isArray(data.yjsState),
          isOldFormat,
          hasContent: data.yjsState?.content !== undefined,
          preview:
            typeof data.yjsState === "string"
              ? data.yjsState.substring(0, 100)
              : JSON.stringify(data.yjsState).substring(0, 100),
        });

        if (isOldFormat) {
          // Old format: {content: "...", timestamp: ..., version: ...}
          // eslint-disable-next-line no-console
          console.log(
            "[YJS Manager] Detected old JSON format, using content field",
            {
              contentLength: data.yjsState.content?.length || 0,
            }
          );
          this.text.insert(0, data.yjsState.content || "");
        } else if (Array.isArray(data.yjsState)) {
          // New format: array of integers representing binary data
          // eslint-disable-next-line no-console
          console.log("[YJS Manager] Applying YJS binary state update", {
            stateLength: data.yjsState.length,
          });
          Y.applyUpdate(this.doc, new Uint8Array(data.yjsState));
        } else {
          // Fallback to raw content
          // eslint-disable-next-line no-console
          console.warn(
            "[YJS Manager] Unknown yjsState format, using raw content",
            {
              yjsStateType: typeof data.yjsState,
              yjsStateConstructor: data.yjsState?.constructor?.name,
            }
          );
          this.text.insert(0, data.raw || "");
        }
      } else {
        // Initialize with current content
        // eslint-disable-next-line no-console
        console.log("[YJS Manager] Initializing with raw content", {
          contentLength: data.raw?.length || 0,
        });
        this.text.insert(0, data.raw || "");
      }

      // Set up change observer
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Setting up observers");
      this.text.observe(this.#onTextChange);

      // Set up document update observer
      this.doc.on("update", this.#onDocumentUpdate);

      // Set initial content in composer
      const initialContent = this.text.toString();
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Setting initial content in composer", {
        contentLength: initialContent.length,
        preview: initialContent.substring(0, 50) + "...",
      });
      this.composer.model.set("reply", initialContent);

      // Watch for composer changes to sync to YJS
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Setting up composer reply watcher");
      this.composer.model.addObserver(
        "reply",
        this,
        this.#onComposerReplyChange
      );

      // Subscribe to message bus for real-time collaboration
      const channel = `/shared_edits/${this.postId}`;
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Subscribing to message bus channel:", channel);
      this.messageBus.subscribe(channel, (message) => {
        // eslint-disable-next-line no-console
        console.log("[YJS Manager] Received message bus update:", {
          messageClientId: message.client_id,
          myClientId: this.messageBus.clientId,
          type: message.type,
          ajaxInProgress: this.ajaxInProgress,
          hasUpdate: !!message.update,
          hasRevision: !!message.revision,
          updateLength: message.update?.length || 0,
          revisionLength: message.revision?.length || 0,
          fullMessage: message,
        });

        const isOwnMessage = message.client_id === this.messageBus.clientId;
        const shouldApply =
          !isOwnMessage &&
          !this.ajaxInProgress &&
          message.type === "yjs-update";

        // eslint-disable-next-line no-console
        console.log("[YJS Manager] Message processing decision:", {
          isOwnMessage,
          shouldApply,
          reason: isOwnMessage
            ? "own message"
            : !shouldApply
              ? "ajax in progress or wrong type"
              : "will apply",
        });

        if (shouldApply) {
          // Try update first, then revision as fallback
          let updateData = message.update || message.revision;

          if (updateData) {
            // If it's a string (JSON), parse it first
            if (typeof updateData === "string") {
              try {
                // eslint-disable-next-line no-console
                console.log(
                  "[YJS Manager] Update data is string, parsing JSON",
                  {
                    stringLength: updateData.length,
                  }
                );
                updateData = JSON.parse(updateData);
              } catch (e) {
                // eslint-disable-next-line no-console
                console.error(
                  "[YJS Manager] Failed to parse update data JSON:",
                  e
                );
                return;
              }
            }

            // eslint-disable-next-line no-console
            console.log(
              "[YJS Manager] Applying remote update from message bus",
              {
                usingField: message.update ? "update" : "revision",
                dataType: typeof updateData,
                isArray: Array.isArray(updateData),
                dataLength: updateData?.length,
              }
            );
            this.#applyYjsUpdate(updateData);
          } else {
            // eslint-disable-next-line no-console
            console.warn("[YJS Manager] No update data found in message");
          }
        }
      });
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Subscribe completed successfully");
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[YJS Manager] Subscribe failed:", e);
      popupAjaxError(e);
    }
  }

  async commit() {
    // eslint-disable-next-line no-console
    console.log("[YJS Manager] Commit called", {
      postId: this.postId,
      storedPostId: this.postId,
      composerPostId: this.#postId,
      hasDoc: !!this.doc,
      version: this.version,
    });

    if (!this.postId) {
      // eslint-disable-next-line no-console
      console.error("[YJS Manager] No post ID available, cannot commit");
      return;
    }
    try {
      const Y = await this.#loadYjs();

      // Clean up observers and connections
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Cleaning up observers and subscriptions");
      if (this.text) {
        this.text.unobserve(this.#onTextChange);
      }

      if (this.doc) {
        this.doc.off("update", this.#onDocumentUpdate);
      }

      // Remove composer observer
      if (this.composer.model) {
        this.composer.model.removeObserver(
          "reply",
          this,
          this.#onComposerReplyChange
        );
      }

      this.messageBus.unsubscribe(`/shared_edits/${this.postId}`);

      // Send final state to server
      const finalState = Y.encodeStateAsUpdate(this.doc);
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Sending final state to server", {
        stateLength: finalState.length,
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
      console.log("[YJS Manager] Commit successful, cleaning up");
      // Clean up
      this.doc = null;
      this.text = null;
      this.version = null;
      this.postId = null;
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[YJS Manager] Commit failed:", e);
      popupAjaxError(e);
    }
  }

  get #postId() {
    return this.composer.model?.post.id;
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

  async #sendUpdate() {
    if (!this.postId || !this.doc || this.ajaxInProgress) {
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Send update skipped", {
        hasPostId: !!this.postId,
        hasDoc: !!this.doc,
        ajaxInProgress: this.ajaxInProgress,
      });
      return;
    }

    // Track when we last sent an update for throttling
    this.lastUpdateSent = new Date();

    // eslint-disable-next-line no-console
    console.log("[YJS Manager] Sending update to server", {
      postId: this.postId,
      version: this.version,
    });

    const Y = await this.#loadYjs();
    this.ajaxInProgress = true;

    try {
      const update = Y.encodeStateAsUpdate(this.doc);
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Encoded update", {
        updateLength: update.length,
      });

      // Get the current text content
      const currentText = this.text.toString();

      const result = await ajax(`/shared_edits/p/${this.postId}`, {
        method: "PUT",
        data: {
          yjsUpdate: Array.from(update),
          version: this.version,
          client_id: this.messageBus.clientId,
          raw: currentText, // Send the actual text for committing
        },
      });

      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Server response:", {
        newVersion: result.version,
        hasYjsUpdate: !!result.yjsUpdate,
      });

      // Apply any server-side transformations
      if (result.yjsUpdate) {
        let updateData = result.yjsUpdate;

        // Parse if it's a JSON string
        if (typeof updateData === "string") {
          try {
            // eslint-disable-next-line no-console
            console.log("[YJS Manager] Server response is string, parsing");
            updateData = JSON.parse(updateData);
          } catch (e) {
            // eslint-disable-next-line no-console
            console.error("[YJS Manager] Failed to parse server response:", e);
            updateData = null;
          }
        }

        if (updateData) {
          // eslint-disable-next-line no-console
          console.log("[YJS Manager] Applying server transformation");
          this.#applyYjsUpdate(updateData);
        }
      }

      this.version = result.version;
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[YJS Manager] Send update failed:", e);
      throw e;
    } finally {
      this.ajaxInProgress = false;
    }
  }

  async #applyYjsUpdate(updateArray) {
    if (!this.doc || this.ajaxInProgress) {
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Apply update skipped", {
        hasDoc: !!this.doc,
        ajaxInProgress: this.ajaxInProgress,
      });
      return;
    }

    try {
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Applying YJS update", {
        updateArrayType: typeof updateArray,
        updateArrayConstructor: updateArray?.constructor?.name,
        isArray: Array.isArray(updateArray),
        updateArrayLength: updateArray?.length,
        firstFewElements:
          Array.isArray(updateArray) && updateArray.length > 0
            ? updateArray.slice(0, 10)
            : "not an array",
      });

      // Validate the update data
      if (!updateArray) {
        // eslint-disable-next-line no-console
        console.error("[YJS Manager] Update data is null or undefined");
        return;
      }

      if (!Array.isArray(updateArray)) {
        // eslint-disable-next-line no-console
        console.error(
          "[YJS Manager] Update data is not an array:",
          typeof updateArray
        );
        return;
      }

      if (updateArray.length === 0) {
        // eslint-disable-next-line no-console
        console.warn("[YJS Manager] Update array is empty, skipping");
        return;
      }

      const Y = await this.#loadYjs();
      const update = new Uint8Array(updateArray);

      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Created Uint8Array", {
        uint8ArrayLength: update.length,
        firstBytes: Array.from(update.slice(0, 10)),
      });

      Y.applyUpdate(this.doc, update);

      // Update composer content
      const newContent = this.text.toString();
      const currentReply = this.composer.model.reply;
      // eslint-disable-next-line no-console
      console.log("[YJS Manager] Update applied successfully", {
        newContentLength: newContent.length,
        currentReplyLength: currentReply?.length,
        contentChanged: newContent !== currentReply,
      });
      if (newContent !== currentReply) {
        // eslint-disable-next-line no-console
        console.log("[YJS Manager] Updating composer reply");
        this.composer.model.set("reply", newContent);
      }
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(
        "[YJS Manager] Failed to apply Yjs update:",
        e,
        "\nUpdate data:",
        updateArray
      );
    }
  }

  /**
   * Get the current document state as a snapshot
   * @returns {Object} Document state with version and content
   */
  async getDocumentState() {
    if (!this.doc) {
      return null;
    }

    const Y = await this.#loadYjs();

    return {
      version: this.version,
      content: this.text.toString(),
      yjsState: Array.from(Y.encodeStateAsUpdate(this.doc)),
    };
  }

  /**
   * Check if the manager is currently active
   * @returns {boolean} True if actively managing a shared edit session
   */
  get isActive() {
    return this.doc !== null && this.text !== null;
  }
}
