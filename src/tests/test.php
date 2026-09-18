<?php
/**
 * Sample check used by the test scripts.
 *
 * This file is ordinary PHP. It is not compiled.
 * The test runner loads the built add-on first, then executes this file.
 *
 * Use the same constant name as in src/main/functions.php.
 * The value below must match what you compiled. After a rename or a
 * value change, run the build again, then this test.
 */
echo 'Simple PHP execution test' . PHP_EOL;
echo 'Testing constant `CORE_BASE_VERSIONS`' . PHP_EOL;
echo CORE_BASE_VERSIONS . PHP_EOL;
