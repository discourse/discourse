MAX_IMAGE_BYTES = 20 * 1024 * 1024
MAX_TOTAL_BYTES = 50 * 1024 * 1024


def image_extension(content):
    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    if content.startswith(b"\xff\xd8\xff"):
        return "jpg"
    if content.startswith((b"GIF87a", b"GIF89a")):
        return "gif"
    if content.startswith(b"RIFF") and content[8:12] == b"WEBP":
        return "webp"
    raise ValueError("The card attachment is not a supported image")


def download_images(board, card):
    attachments = card.get("attachments", [])
    if len(attachments) > 50:
        raise ValueError("The card has more than 50 images; reduce its attachments before retrying")
    total = 0
    seen = set()
    for index, attachment in enumerate(attachments):
        identity = attachment["id"]
        path = attachment["url"]
        if not isinstance(identity, int) or path != f"/codex-board-bot/uploads/{identity}":
            raise ValueError("Refusing a card image outside the authenticated board upload route")
        if identity in seen:
            continue
        seen.add(identity)
        for attempt in range(2):
            response = board.session.get(board.root + path, timeout=30, stream=True, allow_redirects=False)
            if response.status_code in (401, 403) and attempt == 0:
                response.close()
                board.login("codex-bot")
                continue
            with response:
                response.raise_for_status()
                if response.status_code != 200:
                    raise ValueError("The board image did not return image bytes")
                content = bytearray()
                for chunk in response.iter_content(64 * 1024):
                    content.extend(chunk)
                    total += len(chunk)
                    if len(content) > MAX_IMAGE_BYTES or total > MAX_TOTAL_BYTES:
                        raise ValueError("Card images exceed the 20 MB per image or 50 MB total limit")
                extension = image_extension(content)
                yield f"{index:03d}-{identity}.{extension}", bytes(content)
            break
