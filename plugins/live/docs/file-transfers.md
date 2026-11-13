# User-to-user file transfers

File transfers are optional and **disabled by default**. Configure sender groups in
`live_file_transfer_allowed_groups` together with `live_enabled` to let permitted
participants in mesh (peer-to-peer) rooms send files. The per-file maximum is
configured by `live_file_transfer_max_size_mb`: **100 MiB by default**, with an
integer range of **1–102400 MiB (100 GiB)**. Despite the conventional `_mb` name,
units are binary MiB (**1 MiB = 1,048,576 bytes**), not decimal MB. The picker,
outgoing metadata, incoming offers, and acceptance use the current configured
limit; lowering it can invalidate pending offers before storage is allocated.
LiveKit rooms do not support this feature. The data channel is negotiated even
when transfers are disabled, so reserving the channel does not require later
renegotiation. The group setting uses the same permission-refresh behavior as
direct calls. Eligibility is checked again when sending or accepting a file. The group list is
empty by default; empty disables both outgoing and incoming transfers. Only the
initiator needs membership in a sender group, in addition to Live access. There
is no administrator bypass. Recipients need not belong to sender groups, but
both users must be joined to the same mesh room. Receivers validate the sender’s
server-attested `can_send_files` roster permission rather than trusting channel
metadata. Group configuration uses a page refresh, like direct-call permissions;
roster grants reflect membership at the latest server roster serialization.

## Sending and receiving

1. Join a mesh room and wait for the connection to the recipient to open.
2. Open the participant menu from the sidebar or a video tile. Both use the same
   menu component. Choose **Send file…**, then select one file from your device.
   The action is hidden for yourself, unavailable peers, rooms you have not
   joined, non-mesh rooms, and when the setting is disabled.
3. The recipient sees the sender, room, filename, and size in the **File
   transfers** panel. They must explicitly **Accept** or **Reject** the offer.
4. The panel shows transfer status/progress and cancellation controls. It remains
   available when the participant menu closes, when the call widget is hidden,
   and while browsing other Discourse pages. The panel sits below the header,
   away from the bottom call controls and beneath dropdown menus. Use its
   **Collapse**/**Expand** button to uncover page controls; the compact header
   keeps a count of pending incoming offers. A new incoming offer expands the
   panel again, but progress updates do not. A scrollable, height-limited panel
   keeps multiple offers accessible.
5. After receiving completes, choose **Save file** to download an attachment.
   Receiving never automatically saves, previews, opens, or executes content.
   Filenames are sanitized and the download uses `application/octet-stream`.
   Save lazily obtains a disk-backed File; it does not rebuild the file in RAM.
   Temporary download object URLs are revoked by Discourse’s download helper.
   Sender completion waits for the receiver’s completion acknowledgement.
6. **Dismiss** removes finished transfers. Normal cancellation, dismissal, and
   leaving the room delete their temporary disk files, except that a file exported
   by **Save file** is retained for a **30-second** grace period so an immediate Dismiss
   or Leave does not invalidate the browser download. Files awaiting deletion remain
   charged against the receive-disk budget of **twice the current configured
   per-file maximum** until deletion succeeds. Save starts the download;
   it does not confirm that the browser has finished it. Saving does not
   automatically dismiss the transfer, so a failed save can be retried while the
   transfer remains available.

## Privacy and limitations

- File contents travel through an encrypted WebRTC data channel between browsers.
  A TURN server may relay encrypted traffic when a direct connection is not
  possible. Peer-to-peer does not necessarily mean a direct network path.
- Files are **not uploaded to Discourse**, made into Discourse uploads, stored as
  posts/chat attachments, or scanned for viruses. Only accept files from people
  you trust. Downloading safely does not make the contents safe to open later.
- This is a live session feature, not durable/offline delivery. Both people must
  stay connected; leaving or disconnecting interrupts unfinished transfers.
  Reloading or closing the browser loses the transfer UI and session access to
  received files, but does **not** guarantee immediate deletion of OPFS content.
  Orphaned temporary files, including unfinished receives, may remain on disk.
  Files use a timestamped namespace; a later receive attempts cleanup of stale
  orphan files older than **24 hours**. Cleanup is not a background timer and
  requires another receive. Web Locks prevent cleanup from deleting files still
  retained by other tabs.
- Receiving requires origin-private file storage (OPFS) **and Web Locks**, with
  **no RAM fallback**. Unsupported browsers fail acceptance with a clear
  storage-unavailable message; quota or write failures show a storage failure
  message. Sending does not require these receiving capabilities. Browser storage
  quotas and eviction can limit or remove temporary content; it is not durable
  storage.
- Before acknowledging acceptance or allocating an OPFS file, the receiver checks
  `navigator.storage.estimate()` when available. If the reported remaining quota
  cannot fit the file plus the unwritten portions of other accepted receives,
  the offer is declined with a clear not-enough-browser-storage message. Already
  persisted files are not counted twice. Missing, invalid, or rejected estimates
  do not block otherwise supported receives. This is an advisory check, not a
  physical disk-space guarantee or quota reservation; other tabs and browser
  activity can change availability, so write/close failures still cancel safely
  and clean up partial files.
- Received bytes are written incrementally. A bounded **256 KiB** streaming
  window and receiver acknowledgements after disk writes limit outstanding data
  rather than buffering a full file in memory. This window does not grow when the
  configured per-file maximum is raised. Temporary receive disk reservations are
  limited to **2× the current configured per-file maximum** (200 MiB by default),
  including initializing, active, completed, and retiring files until deletion.
  Browser storage quotas still apply, even when the configured limit is higher.
  Limits remain **four active incoming offers**, **one active transfer per peer**,
  and **100 retained history entries**. Cancel or dismiss old transfers before
  retrying when capacity is full.
- The UI consumes the live WebRTC service’s reactive `fileTransfers` array and
  consent/cancel/dismiss methods. It never handles data-channel protocol traffic.
