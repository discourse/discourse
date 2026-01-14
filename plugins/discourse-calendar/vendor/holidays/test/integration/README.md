# Integration tests

These tests are dependent on the files in /definitions (and, by proxy, /lib/generated_definitions).
It is possible that these tests will break because of 'unrelated' definition changes. The code
behind these changes could still be good but since the definitions changed we could see failures.

These are not unit tests. This is not testing whether specific internal code is working. These are
tests from the consumer perspective. You must recognize that this could fail because of code
changes unrelated to definition changes.
