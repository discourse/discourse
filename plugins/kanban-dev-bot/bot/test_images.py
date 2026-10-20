import unittest
from unittest.mock import Mock

from image_inputs import download_images, image_extension


class ImageTests(unittest.TestCase):
    def board(self, content):
        board = Mock(root="https://board.example")
        response = board.session.get.return_value
        response.status_code = 200
        response.__enter__ = Mock(return_value=response)
        response.__exit__ = Mock(return_value=False)
        response.iter_content.return_value = [content]
        return board

    def test_authenticated_png_download_preserves_bytes(self):
        content = b"\x89PNG\r\n\x1a\n" + b"image"
        board = self.board(content)
        result = list(download_images(board, {"attachments": [{"id": 42, "url": "/codex-board-bot/uploads/42"}]}))
        self.assertEqual(result, [("000-42.png", content)])
        self.assertEqual(board.session.get.call_args.args[0], "https://board.example/codex-board-bot/uploads/42")

    def test_arbitrary_urls_are_rejected_before_any_request(self):
        board = self.board(b"")
        with self.assertRaisesRegex(ValueError, "authenticated board"):
            list(download_images(board, {"attachments": [{"id": 1, "url": "https://other.example/secret"}]}))
        board.session.get.assert_not_called()

    def test_html_error_pages_are_not_passed_as_images(self):
        with self.assertRaisesRegex(ValueError, "supported image"):
            image_extension(b"<html>not an image</html>")

    def test_duplicate_attachment_is_only_attached_once(self):
        board = self.board(b"GIF89a" + b"image")
        image = {"id": 1, "url": "/codex-board-bot/uploads/1"}
        self.assertEqual(len(list(download_images(board, {"attachments": [image, image]}))), 1)


if __name__ == "__main__":
    unittest.main()
