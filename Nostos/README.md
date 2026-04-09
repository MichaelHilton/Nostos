# Nostos — Local development notes

Testing and coverage

- Run tests:

  ```bash
  make test
  ```

- Run tests and generate HTML coverage report:

  ```bash
  make coverage
  # or
  ./scripts/test-with-coverage.sh
  ```

The generated HTML coverage report will be at `coverage/index.html`. In CI the `coverage` folder is uploaded as an artifact.
